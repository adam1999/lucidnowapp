import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/dream.dart';

class DreamCard extends StatelessWidget {
  final DreamEntry dreamEntry;
  final VoidCallback onTap;

  const DreamCard({
    super.key,
    required this.dreamEntry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252531).withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0, bottom: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dream content section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: dreamEntry.dreams.asMap().entries.map((entry) {
                        final index = entry.key;
                        final dream = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index > 0)
                              Column(
                                children: [
                                  const SizedBox(height: 14),
                                  Container(
                                    height: 1,
                                    width: double.infinity,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ),
                            if (dream.isLucid)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5E5DE3).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'LUCID',
                                  style: TextStyle(
                                    color: Color(0xFF5E5DE3),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              dream.content,
                              style: const TextStyle(fontSize: 16, color: Colors.white),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Divider between content and footer
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    const SizedBox(height: 1),
                    // Footer with date and settings button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE, MMM d, y').format(dreamEntry.date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: onTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}