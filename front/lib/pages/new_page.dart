import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../app/theme/app_theme.dart';
import '../widgets/global/global_logo_bar.dart';
import '../models/qa_pair.dart';
import '../telegram_safe_area.dart';

class NewPage extends StatefulWidget {
  final String title;

  const NewPage({super.key, required this.title});

  @override
  State<NewPage> createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> with TickerProviderStateMixin {
  // Helper method to calculate adaptive bottom padding
  double _getAdaptiveBottomPadding() {
    final service = TelegramSafeAreaService();
    final safeAreaInset = service.getSafeAreaInset();

    // Formula: bottom SafeAreaInset + 30px
    final bottomPadding = safeAreaInset.bottom + 30;
    return bottomPadding;
  }

  // List to store all Q&A pairs
  final List<QAPair> _qaPairs = [];
  final String _apiUrl = 'https://xp7k-production.up.railway.app';
  // API Key - read from window.APP_CONFIG.API_KEY at runtime
  String? _apiKey;
  bool _isLoadingApiKey = false;
  late AnimationController _dotsController;


  // Scroll controller for auto-scrolling to new responses
  final ScrollController _scrollController = ScrollController();

  // Track if auto-scrolling is enabled (disabled when user manually scrolls)
  bool _autoScrollEnabled = true;

  // Scroll progress for custom scrollbar
  double _scrollProgress = 0.0;
  double _scrollIndicatorHeight = 1.0;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Load API key from Vercel serverless function (reads from env vars at runtime)
    // Don't await here - it will load in the background
    _loadApiKey();

    // Listen to scroll changes to detect manual scrolling and update scrollbar
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final maxScroll = position.maxScrollExtent;
        final currentScroll = position.pixels;
        final viewportHeight = position.viewportDimension;
        final totalHeight = viewportHeight + maxScroll;

        // Update scrollbar
        if (maxScroll > 0 && totalHeight > 0) {
          final indicatorHeight =
              (viewportHeight / totalHeight).clamp(0.0, 1.0);
          final scrollPosition = (currentScroll / maxScroll).clamp(0.0, 1.0);
          setState(() {
            _scrollIndicatorHeight = indicatorHeight;
            _scrollProgress = scrollPosition;
          });
        } else {
          setState(() {
            _scrollProgress = 0.0;
            _scrollIndicatorHeight = 1.0;
          });
        }

        // If user is near the bottom (within 50px), re-enable auto-scroll
        // Otherwise, disable auto-scroll if user scrolled up
        if (maxScroll > 0) {
          final distanceFromBottom = maxScroll - currentScroll;
          if (distanceFromBottom < 50) {
            // User is near bottom, enable auto-scroll
            // Also check if any response is still loading/streaming
            final hasLoadingContent = _qaPairs.any((pair) => pair.isLoading);
            if (!_autoScrollEnabled || hasLoadingContent) {
              setState(() {
                _autoScrollEnabled = true;
              });
              // If content is still streaming and user is at bottom, scroll immediately
              if (hasLoadingContent) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    final currentMaxScroll =
                        _scrollController.position.maxScrollExtent;
                    if (currentMaxScroll > 0) {
                      _scrollController.animateTo(
                        currentMaxScroll,
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                      );
                    }
                  }
                });
              }
            }
          } else if (distanceFromBottom > 100) {
            // User scrolled up significantly, disable auto-scroll
            if (_autoScrollEnabled) {
              setState(() {
                _autoScrollEnabled = false;
              });
            }
          }
        }
      }
    });

    // Add initial Q&A pair with the title
    setState(() {
      _qaPairs.add(QAPair(
        question: widget.title,
        isLoading: true,
        dotsController: _dotsController,
      ));
    });
    // Fetch response after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _qaPairs.isNotEmpty) {
        _fetchAIResponse(_qaPairs.last);
      }
    });
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _scrollController.dispose();
    // Dispose all animation controllers
    for (var pair in _qaPairs) {
      pair.dotsController?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingApiKey) {
      print('API key load already in progress, waiting...');
      // Wait for existing load to complete
      while (_isLoadingApiKey) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _isLoadingApiKey = true;
    try {
      // First, try to load from .env file (for local development)
      try {
        final envApiKey = dotenv.env['API_KEY'];
        if (envApiKey != null && envApiKey.isNotEmpty) {
          _apiKey = envApiKey;
          if (mounted) {
            setState(() {
              _apiKey = envApiKey;
            });
          }
          print('API key loaded from .env file (local development)');
          _isLoadingApiKey = false;
          return;
        }
      } catch (e) {
        print('No API key found in .env file: $e');
      }

      // Try to fetch API key from Vercel serverless function
      // This reads from Vercel's environment variables at runtime
      final uri = Uri.parse('/api/config');

      try {
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final apiKey = data['apiKey'] as String?;

          if (apiKey != null && apiKey.isNotEmpty) {
            _apiKey = apiKey;
            if (mounted) {
              setState(() {
                _apiKey = apiKey;
              });
            }
            print(
                'API key loaded from Vercel environment variable: ${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}...');
            _isLoadingApiKey = false;
            return;
          } else {
            print('API key from serverless function is empty or null');
          }
        } else {
          print('API key fetch failed with status: ${response.statusCode}');
        }
      } catch (e) {
        print('Error fetching API key from serverless function: $e');
      }

      // Fallback: try to read from window.APP_CONFIG (for local development)
      try {
        final apiKeyJs = js.context.callMethod(
            'eval', ['window.APP_CONFIG && window.APP_CONFIG.API_KEY || ""']);

        if (apiKeyJs != null) {
          final apiKey = apiKeyJs.toString();
          if (apiKey.isNotEmpty && apiKey != '{{API_KEY}}') {
            _apiKey = apiKey;
            if (mounted) {
              setState(() {
                _apiKey = apiKey;
              });
            }
            print('API key loaded from window.APP_CONFIG (fallback)');
            _isLoadingApiKey = false;
            return;
          }
        }
      } catch (e) {
        print('Error reading API key from window: $e');
      }

      print('API key not found');
      _apiKey = '';
      if (mounted) {
        setState(() {
          _apiKey = '';
        });
      }
    } catch (e) {
      print('Error loading API key: $e');
      _apiKey = '';
      if (mounted) {
        setState(() {
          _apiKey = '';
        });
      }
    } finally {
      _isLoadingApiKey = false;
    }
  }

  Future<void> _fetchAIResponse(QAPair pair) async {
    try {
      // Wait for API key to be loaded if not set
      if (_apiKey == null || _apiKey!.isEmpty) {
        print('API key not set, loading...');
        await _loadApiKey();
        // Wait a bit more to ensure state is updated
        await Future.delayed(const Duration(milliseconds: 200));
        print(
            'After loading, API key is: ${_apiKey != null && _apiKey!.isNotEmpty ? "set (length: ${_apiKey!.length})" : "empty"}');
      }

      if (_apiKey == null || _apiKey!.isEmpty) {
        print('API key still empty after loading attempt');
        if (mounted) {
          setState(() {
            pair.error =
                'API key not configured. Please set API_KEY environment variable.';
            pair.isLoading = false;
            pair.dotsController?.stop();
          });
        }
        return;
      }

      print('Using API key for request (length: ${_apiKey!.length})');

      final request = http.Request(
        'POST',
        Uri.parse('$_apiUrl/api/chat'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.headers['X-API-Key'] = _apiKey ?? '';
      request.body = jsonEncode({'message': pair.question});

      final client = http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode == 200) {
        String accumulatedResponse = '';
        String? finalResponse;
        String buffer = ''; // Buffer for incomplete lines

        // Process the stream line by line as it arrives
        await for (final chunk
            in streamedResponse.stream.transform(utf8.decoder)) {
          buffer += chunk;
          final lines = buffer.split('\n');

          // Keep the last incomplete line in buffer
          if (lines.isNotEmpty) {
            buffer = lines.removeLast();
          } else {
            buffer = '';
          }

          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            try {
              final data = jsonDecode(line);

              // Check for final complete response
              if (data['response'] != null && data['done'] == true) {
                finalResponse = data['response'] as String;
                // Update with final complete response
                if (mounted) {
                  setState(() {
                    pair.response = finalResponse;
                    pair.isLoading = false;
                    pair.dotsController?.stop();
                  });
                }
              }
              // Process tokens as they arrive (for streaming effect)
              else if (data['token'] != null) {
                accumulatedResponse += data['token'] as String;
                // Update UI immediately with each token (streaming effect)
                if (mounted && finalResponse == null) {
                  setState(() {
                    pair.response = accumulatedResponse;
                    pair.isLoading = false;
                    pair.dotsController?.stop();
                  });
                  // Auto-scroll to bottom as response streams in, only if auto-scroll is enabled
                  if (_autoScrollEnabled) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        final maxScroll =
                            _scrollController.position.maxScrollExtent;
                        if (maxScroll > 0) {
                          _scrollController.animateTo(
                            maxScroll,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeOut,
                          );
                        }
                      }
                    });
                  }
                }
              }
              // Check for errors
              else if (data['error'] != null) {
                if (mounted) {
                  setState(() {
                    pair.error = data['error'] as String;
                    pair.isLoading = false;
                    pair.dotsController?.stop();
                  });
                }
                client.close();
                return;
              }
            } catch (e) {
              // Skip invalid JSON lines (might be partial chunks)
              continue;
            }
          }
        }

        // Process any remaining buffer content
        if (buffer.trim().isNotEmpty) {
          try {
            final data = jsonDecode(buffer);
            if (data['response'] != null && data['done'] == true) {
              finalResponse = data['response'] as String;
            } else if (data['token'] != null) {
              accumulatedResponse += data['token'] as String;
            }
          } catch (e) {
            // Ignore parse errors for buffer
          }
        }

        // Use final response if available, otherwise use accumulated
        if (mounted && finalResponse != null) {
          setState(() {
            pair.response = finalResponse;
            pair.isLoading = false;
            pair.dotsController?.stop();
          });
          // Scroll to bottom when response is complete, only if auto-scroll is enabled
          if (_autoScrollEnabled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final maxScroll = _scrollController.position.maxScrollExtent;
                if (maxScroll > 0) {
                  _scrollController.animateTo(
                    maxScroll,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              }
            });
          }
        } else if (mounted &&
            accumulatedResponse.isNotEmpty &&
            pair.response == null) {
          setState(() {
            pair.response = accumulatedResponse;
            pair.isLoading = false;
            pair.dotsController?.stop();
          });
          // Scroll to bottom when response is complete, only if auto-scroll is enabled
          if (_autoScrollEnabled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final maxScroll = _scrollController.position.maxScrollExtent;
                if (maxScroll > 0) {
                  _scrollController.animateTo(
                    maxScroll,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              }
            });
          }
        }

        client.close();
      } else {
        if (mounted) {
          setState(() {
            pair.error = 'Error: ${streamedResponse.statusCode}';
            pair.isLoading = false;
            pair.dotsController?.stop();
          });
        }
        client.close();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          pair.error = 'Failed to connect: $e';
          pair.isLoading = false;
          pair.dotsController?.stop();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thickness: WidgetStateProperty.all(0.0),
          thumbVisibility: WidgetStateProperty.all(false),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<bool>(
            valueListenable: GlobalLogoBar.fullscreenNotifier,
            builder: (context, isFullscreen, child) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: _getAdaptiveBottomPadding(),
                    top: GlobalLogoBar.getContentTopPadding()),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      //padding: const EdgeInsets.all(15),
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                reverse: false,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20.0, right: 20.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children:
                                        _qaPairs.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final pair = entry.value;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Question
                                          Text(
                                            pair.question,
                                            style: const TextStyle(
                                              fontFamily: 'Aeroport',
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400,
                                              color: Color.fromARGB(
                                                  255, 255, 255, 255),
                                            ),
                                            textAlign: TextAlign.left,
                                          ),
                                          const SizedBox(height: 16),
                                          // Response (loading, error, or content)
                                          if (pair.isLoading &&
                                              pair.dotsController != null)
                                            AnimatedBuilder(
                                              animation: pair.dotsController!,
                                              builder: (context, child) {
                                                final progress =
                                                    pair.dotsController!.value;
                                                int dotCount = 1;
                                                if (progress < 0.33) {
                                                  dotCount = 1;
                                                } else if (progress < 0.66) {
                                                  dotCount = 2;
                                                } else {
                                                  dotCount = 3;
                                                }
                                                return Text(
                                                  '·' * dotCount,
                                                  style: const TextStyle(
                                                    fontFamily: 'Aeroport',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color.fromARGB(
                                                        255, 255, 255, 255),
                                                  ),
                                                  textAlign: TextAlign.left,
                                                );
                                              },
                                            )
                                          else if (pair.error != null)
                                            Text(
                                              pair.error!,
                                              style: const TextStyle(
                                                fontFamily: 'Aeroport',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.red,
                                              ),
                                              textAlign: TextAlign.left,
                                            )
                                          else if (pair.response != null)
                                            Text(
                                              pair.response!,
                                              style: const TextStyle(
                                                fontFamily: 'Aeroport',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                                color: Color(0xFFFFFFFF),
                                              ),
                                              textAlign: TextAlign.left,
                                            )
                                          else
                                            const Text(
                                              'No response received',
                                              style: TextStyle(
                                                fontFamily: 'Aeroport',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                                color: Color(0xFFFFFFFF),
                                              ),
                                            ),
                                          // Add spacing between Q&A pairs (except for the last one in reversed list)
                                          if (index < _qaPairs.length - 1)
                                            const SizedBox(height: 32),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            // Custom scrollbar - always visible on mobile
                            // Position it as a separate row item to ensure it's always in viewport
                            SizedBox(
                              width: 1.0,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Check for valid constraints and scroll controller
                                  if (!_scrollController.hasClients ||
                                      constraints.maxHeight ==
                                          double.infinity ||
                                      constraints.maxHeight <= 0) {
                                    return const SizedBox.shrink();
                                  }

                                  try {
                                    final maxScroll = _scrollController
                                        .position.maxScrollExtent;
                                    if (maxScroll <= 0) {
                                      return const SizedBox.shrink();
                                    }

                                    final containerHeight =
                                        constraints.maxHeight;
                                    final indicatorHeight = (containerHeight *
                                            _scrollIndicatorHeight)
                                        .clamp(0.0, containerHeight);
                                    final availableSpace =
                                        (containerHeight - indicatorHeight)
                                            .clamp(0.0, containerHeight);
                                    final topPosition =
                                        (_scrollProgress * availableSpace)
                                            .clamp(0.0, containerHeight);

                                    // Only show white thumb, no grey track background
                                    return Align(
                                      alignment: Alignment.topCenter,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.only(top: topPosition),
                                        child: Container(
                                          width: 1.0,
                                          height: indicatorHeight.clamp(
                                              0.0, containerHeight),
                                          color: const Color(0xFFFFFFFF),
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    // Return empty widget if any error occurs
                                    return const SizedBox.shrink();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
              );
            },
          ),
        ),
      ),
    );
  }
}

