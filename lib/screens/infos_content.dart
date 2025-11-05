import 'package:flutter/material.dart';
import '../token_storage.dart';
import '../utils/app_colors.dart';
import 'dart:convert';

class NotificationItem {
	final String id;
	final String title;
	final String body;
	bool read;

	NotificationItem({
		required this.id,
		required this.title,
		required this.body,
		this.read = false,
	});

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'title': title,
			'body': body,
			'read': read ? 1 : 0,
		};
	}

	static NotificationItem fromMap(Map<String, dynamic> m) {
		return NotificationItem(
			id: m['id'] as String? ?? '',
			title: m['title'] as String? ?? '',
			body: m['body'] as String? ?? '',
			read: (m['read'] == 1 || m['read'] == true),
		);
	}
}

class InfosContent extends StatefulWidget {
	const InfosContent({super.key});

	@override
	State<InfosContent> createState() => _InfosContentState();
}

class _InfosContentState extends State<InfosContent> {
	final List<NotificationItem> _items = [];

	@override
	void initState() {
		super.initState();
		_loadCachedNotifications();
	}

	Future<void> _loadCachedNotifications() async {
		try {
			final jsonStr = await TokenStorage.readCachedNotifications();
			if (jsonStr != null && jsonStr.isNotEmpty) {
				final List<dynamic> arr = jsonDecode(jsonStr) as List<dynamic>;
				final loaded = arr.map((e) => NotificationItem.fromMap(e as Map<String, dynamic>)).toList();
				setState(() {
					_items.clear();
					_items.addAll(loaded);
				});
				return;
			}
		} catch (e) {
			print('Erreur lecture cache notifications: $e');
		}

		// fallback: generate demo items
		setState(() {
			_items.clear();
			_items.addAll(List.generate(
				8,
				(i) => NotificationItem(
					id: 'n$i',
					title: 'Notification ${i + 1}',
					body: 'Ceci est le détail de la notification ${i + 1}.',
					read: i % 3 == 0,
				),
			));
		});
		_saveCachedNotifications();
	}

	Future<void> _saveCachedNotifications() async {
		try {
			final arr = _items.map((e) => e.toMap()).toList();
			final s = jsonEncode(arr);
			await TokenStorage.saveCachedNotifications(s);
		} catch (e) {
			print('Erreur sauvegarde cache notifications: $e');
		}
	}

	void _toggleRead(NotificationItem item) {
		setState(() {
			item.read = !item.read;
		});
		_saveCachedNotifications();
	}

	void _markAllRead() {
		setState(() {
			for (final it in _items) {
				it.read = true;
			}
		});
		_saveCachedNotifications();
	}

	int get _unreadCount => _items.where((i) => !i.read).length;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.getPrimaryBackground(context),
			body: Column(
				children: [
					const SizedBox(height: 48),
					Container(
						width: double.infinity,
						padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
						color: AppColors.getPrimaryBackground(context),
						child: Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								Text(
									'Notifications (${_items.length})',
									style: const TextStyle(
										fontWeight: FontWeight.bold,
										color: AppColors.primaryButton,
									),
								),
								Row(
									children: [
										Text(
											'Non lues: $_unreadCount',
											style: const TextStyle(color: AppColors.secondaryText),
										),
										const SizedBox(width: 16),
										TextButton.icon(
											onPressed: _markAllRead,
											icon: const Icon(Icons.done_all, color: AppColors.primaryButton),
											label: const Text(
												'Tout lire',
												style: TextStyle(color: AppColors.primaryButton),
											),
										),
									],
								),
							],
						),
					),
					Expanded(
						child: ListView.separated(
							padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
							itemCount: _items.length,
							separatorBuilder: (_, __) => const SizedBox(height: 8),
							itemBuilder: (context, index) {
								final item = _items[index];
								return Material(
									color: item.read
											? AppColors.getCardBackground(context)
											: AppColors.primaryButton.withOpacity(0.2),
									borderRadius: BorderRadius.circular(10),
									child: Container(
										decoration: BoxDecoration(
											borderRadius: BorderRadius.circular(10),
										),
										child: InkWell(
											borderRadius: BorderRadius.circular(10),
											onTap: () => _toggleRead(item),
											child: Padding(
												padding: const EdgeInsets.all(12),
											child: Row(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													// read indicator
													Container(
														width: 10,
														height: 10,
														margin: const EdgeInsets.only(top: 6, right: 12),
														decoration: BoxDecoration(
															shape: BoxShape.circle,
															color: item.read ? Colors.transparent : AppColors.primaryButton,
															border: Border.all(
																color: item.read ? AppColors.getIconDisabled(context) : AppColors.primaryButton,
															),
														),
													),
													// content
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Row(
																	mainAxisAlignment: MainAxisAlignment.spaceBetween,
																	children: [
																		Expanded(
																			child: Text(
																				item.title,
																				style: TextStyle(
																					fontWeight: FontWeight.bold,
																					color: AppColors.getTextPrimary(context),
																				),
																			),
																		),
																		const SizedBox(width: 8),
																		TextButton(
																			onPressed: () => _toggleRead(item),
																			style: TextButton.styleFrom(
																				foregroundColor: AppColors.primaryButton,
																			),
																			child: Text(item.read ? 'Marqué' : 'Marquer lu'),
																		),
																	],
																),
																const SizedBox(height: 6),
																Text(
																	item.body,
																	style: TextStyle(
																		color: AppColors.getTextPrimary(context),
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
				],
			),
		);
	}
}

