import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../services/ai_chat_service.dart';
import '../telegram_safe_area.dart';
import '../utils/app_haptic.dart';
import '../widgets/common/edge_swipe_back.dart';
import '../widgets/global/global_logo_bar.dart';

class AiConversationEntry {
  const AiConversationEntry({
    required this.prompt,
    required this.answer,
    required this.isLoading,
  });

  final String prompt;
  final String answer;
  final bool isLoading;

  AiConversationEntry copyWith({
    String? prompt,
    String? answer,
    bool? isLoading,
  }) {
    return AiConversationEntry(
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AiConversationController {
  AiConversationController._();

  static final AiConversationController instance = AiConversationController._();

  final ValueNotifier<List<AiConversationEntry>> entriesNotifier =
      ValueNotifier<List<AiConversationEntry>>(<AiConversationEntry>[]);

  final AiChatService _chatService = AiChatService();

  Future<void> submitPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    final current = List<AiConversationEntry>.from(entriesNotifier.value);
    final insertedIndex = current.length;
    current.add(
      const AiConversationEntry(
        prompt: '',
        answer: '',
        isLoading: true,
      ),
    );
    current[insertedIndex] = AiConversationEntry(
      prompt: trimmed,
      answer: '',
      isLoading: true,
    );
    entriesNotifier.value = current;

    try {
      final messages = _buildChatMessages(current, insertedIndex);
      final answer = await _chatService.ask(messages: messages);
      final updated = List<AiConversationEntry>.from(entriesNotifier.value);
      if (insertedIndex < updated.length) {
        updated[insertedIndex] = updated[insertedIndex].copyWith(
          answer: answer,
          isLoading: false,
        );
        entriesNotifier.value = updated;
      }
    } catch (_) {
      final updated = List<AiConversationEntry>.from(entriesNotifier.value);
      if (insertedIndex < updated.length) {
        updated[insertedIndex] = updated[insertedIndex].copyWith(
          answer: 'Unable to get AI response right now. Please try again.',
          isLoading: false,
        );
        entriesNotifier.value = updated;
      }
    }
  }

  List<Map<String, String>> _buildChatMessages(
    List<AiConversationEntry> entries,
    int latestIndex,
  ) {
    final messages = <Map<String, String>>[];
    for (var i = 0; i <= latestIndex; i++) {
      final item = entries[i];
      if (item.prompt.trim().isNotEmpty) {
        messages.add({
          'role': 'user',
          'content': item.prompt.trim(),
        });
      }
      final answer = item.answer.trim();
      if (!item.isLoading && answer.isNotEmpty) {
        messages.add({
          'role': 'assistant',
          'content': answer,
        });
      }
    }
    return messages;
  }
}

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final ScrollController _scrollController = ScrollController();

  double _getAdaptiveBottomPadding() {
    final safeAreaInset = TelegramSafeAreaService().getSafeAreaInset();
    return safeAreaInset.bottom + 30;
  }

  void _handleBackButton() {
    AppHaptic.heavy();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _updateScrollIndicator() {
    if (_scrollController.hasClients) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicator);
    AiConversationController.instance.entriesNotifier
        .addListener(_onEntriesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _jumpToBottom();
      }
    });
  }

  @override
  void dispose() {
    AiConversationController.instance.entriesNotifier
        .removeListener(_onEntriesChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onEntriesChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _jumpToBottom();
      }
    });
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = GlobalLogoBar.getContentTopPadding();
    final bottomPadding = _getAdaptiveBottomPadding();
    final entries = AiConversationController.instance.entriesNotifier.value;
    final newestFirst = entries.reversed.toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: EdgeSwipeBack(
        onBack: _handleBackButton,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: topPadding,
                bottom: bottomPadding,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView.separated(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(15, 30, 15, 30),
                    itemCount: newestFirst.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 30),
                    itemBuilder: (context, index) {
                      final entry = newestFirst[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.prompt,
                            style: TextStyle(
                              fontFamily: 'Aeroport',
                              fontSize: 30,
                              height: 1.0,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            entry.isLoading ? 'Thinking...' : entry.answer,
                            style: TextStyle(
                              fontFamily: 'Aeroport',
                              fontSize: 15,
                              height: 2.0,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              right: 5,
              top: topPadding,
              bottom: bottomPadding,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final containerHeight = constraints.maxHeight;
                  if (containerHeight <= 0 || !_scrollController.hasClients) {
                    return const SizedBox.shrink();
                  }

                  try {
                    final position = _scrollController.position;
                    final maxScroll = position.maxScrollExtent;
                    final currentScroll = position.pixels;
                    final viewportHeight = position.viewportDimension;
                    final totalHeight = viewportHeight + maxScroll;

                    if (maxScroll <= 0 || totalHeight <= 0) {
                      return const SizedBox.shrink();
                    }

                    final indicatorHeightRatio =
                        (viewportHeight / totalHeight).clamp(0.0, 1.0);
                    final indicatorHeight =
                        (containerHeight * indicatorHeightRatio)
                            .clamp(0.0, containerHeight);
                    if (indicatorHeight <= 0) {
                      return const SizedBox.shrink();
                    }

                    final scrollPosition =
                        (currentScroll / maxScroll).clamp(0.0, 1.0);
                    final availableSpace = (containerHeight - indicatorHeight)
                        .clamp(0.0, containerHeight);
                    final topPosition = (scrollPosition * availableSpace)
                        .clamp(0.0, containerHeight);

                    return Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: topPosition),
                        child: Container(
                          width: 1,
                          height: indicatorHeight,
                          color: const Color(0xFF818181),
                        ),
                      ),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
