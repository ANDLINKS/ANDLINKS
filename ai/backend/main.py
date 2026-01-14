from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, List, Dict
import httpx
import os
import json

app = FastAPI()

# CORS middleware to allow Flutter app to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ollama API URL - defaults to localhost, can be overridden with env var
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
# Using llama3.2:3b as default - multilingual model optimized for 8GB RAM
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b")

# API Key for authentication - must be set in environment variables
API_KEY = os.getenv("API_KEY")
if not API_KEY:
    raise ValueError("API_KEY environment variable must be set for API security")


def verify_api_key(x_api_key: Optional[str] = Header(None, alias="X-API-Key")):
    """
    Verify API key from X-API-Key header
    """
    if not x_api_key:
        raise HTTPException(
            status_code=401,
            detail="API key required. Please provide X-API-Key header."
        )
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=403,
            detail="Invalid API key"
        )
    return x_api_key


class ChatRequest(BaseModel):
    messages: List[Dict[str, str]]  # Array of ChatMessage objects with role and content


@app.get("/")
async def root():
    return {"status": "ok", "message": "AI Chat API is running"}


@app.post("/api/chat")
async def chat(request: ChatRequest, api_key: str = Depends(verify_api_key)):
    """
    Send messages array to Ollama /api/chat and return streaming AI response
    Requires valid API key in X-API-Key header
    Messages format: [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
    """
    if not request.messages or len(request.messages) == 0:
        raise HTTPException(status_code=400, detail="Messages array cannot be empty")
    
    # Validate messages format according to Ollama ChatMessage spec
    validated_messages = []
    for msg in request.messages:
        if not isinstance(msg, dict):
            continue
        role = msg.get("role", "")
        content = msg.get("content", "")
        # Validate role matches Ollama spec: system, user, assistant, tool
        if role in ["system", "user", "assistant", "tool"] and content:
            validated_messages.append({
                "role": role,
                "content": str(content).strip()
            })
    
    if len(validated_messages) == 0:
        raise HTTPException(status_code=400, detail="No valid messages found")
    
    async def generate_response():
        try:
            # Call Ollama /api/chat endpoint with messages array (according to API spec)
            async with httpx.AsyncClient(timeout=60.0) as client:
                async with client.stream(
                    "POST",
                    f"{OLLAMA_URL}/api/chat",
                    json={
                        "model": OLLAMA_MODEL,
                        "messages": validated_messages,  # Send messages array as per Ollama API spec
                        "stream": True,  # Enable streaming
                        "options": {
                            "num_predict": 1000,  # Maximum tokens to generate
                            "temperature": 0.7,
                            "num_thread": 2,
                        }
                    }
                ) as response:
                    if response.status_code != 200:
                        error_detail = "Unknown error"
                        try:
                            error_text = await response.aread()
                            error_data = json.loads(error_text)
                            error_detail = error_data.get("error", str(error_text))
                        except:
                            error_detail = str(response.status_code)
                        
                        yield json.dumps({"error": f"Ollama error: {error_detail}"}) + "\n"
                        return
                    
                    full_response = ""
                    async for line in response.aiter_lines():
                        if line:
                            try:
                                data = json.loads(line)
                                
                                # Ollama /api/chat streaming format: message.content contains partial text
                                # According to ChatStreamEvent spec: message.content is "Partial assistant message text"
                                if "message" in data and isinstance(data["message"], dict):
                                    content = data["message"].get("content", "")
                                    if content:
                                        full_response += content
                                        # Send each content chunk as it arrives
                                        yield json.dumps({"token": content, "done": data.get("done", False)}) + "\n"
                                
                                # Check if stream is done
                                if data.get("done", False):
                                    # Send final complete response
                                    yield json.dumps({"response": full_response, "done": True}) + "\n"
                                    break
                            except json.JSONDecodeError as e:
                                print(f"Warning: Failed to parse JSON line: {line[:100]}")
                                continue
        
        except httpx.TimeoutException:
            yield json.dumps({"error": "Request timeout - AI model took too long to respond"}) + "\n"
        except httpx.RequestError as e:
            yield json.dumps({"error": f"Cannot connect to Ollama at {OLLAMA_URL}. Error: {str(e)}"}) + "\n"
        except Exception as e:
            yield json.dumps({"error": f"Internal server error: {str(e)}"}) + "\n"
    
    return StreamingResponse(generate_response(), media_type="application/x-ndjson")


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

