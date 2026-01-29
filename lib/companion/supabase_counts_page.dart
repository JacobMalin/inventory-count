import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';

class SupabaseCountsPage extends StatelessWidget {
  const SupabaseCountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Supabase.instance.client.from('counts');

    return SafeArea(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('counts')
            .stream(primaryKey: ['created_at']),
        builder: (context, snapshot) {
          print(snapshot.data);
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final counts = snapshot.data ?? [];
          if (counts.isEmpty) {
            return const Center(child: Text('No counts found.'));
          }

          return ListView.builder(
            itemCount: counts.length,
            itemBuilder: (context, index) {
              final count = counts[index];

              var title = '';
              if (count['created_at'] != null) {
                DateTime? dt;
                if (count['created_at'] is DateTime) {
                  dt = count['created_at'] as DateTime;
                } else {
                  dt = DateTime.tryParse(
                    count['created_at'].toString(),
                  )?.toLocal();
                }
                if (dt != null) {
                  title = DateFormat.yMMMd().add_jm().format(dt);
                } else {
                  title = count['created_at'].toString();
                }
              }

              return ListTile(
                title: Text(title),
                leading: const Icon(Icons.insert_drive_file),
                onTap: () async {
                  try {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Print this count?'),
                        content: Text(
                          'Would you like to print the count uploaded on $title?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed:
                                snapshot.connectionState != ConnectionState.done
                                ? null
                                : () async {
                                    Navigator.of(context).pop();
                                    final doc = pw.Document();
                                    doc.addPage(
                                      pw.MultiPage(
                                        build: (context) => [pw.Text('')],
                                      ),
                                    );
                                    await Printing.layoutPdf(
                                      onLayout: (format) async => doc.save(),
                                    );
                                  },
                            child: const Text('Print'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download failed: $e')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
