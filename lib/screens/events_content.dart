import 'package:flutter/material.dart';
import 'event_details_screen.dart';
import '../utils/app_colors.dart';

class EventItem {
	final String id;
	final String title;
	final String place;
	final DateTime date;

	EventItem({
		required this.id,
		required this.title,
		required this.place,
		required this.date,
	});
}

class EventsContent extends StatefulWidget {
	const EventsContent({super.key});

	@override
	State<EventsContent> createState() => _EventsContentState();
}

class _EventsContentState extends State<EventsContent> {
	final TextEditingController _searchController = TextEditingController();
	List<EventItem> _allEvents = [];
	List<EventItem> _filteredEvents = [];

	@override
	void initState() {
		super.initState();
		// TODO: Replace this mock data by real API/provider data
		_allEvents = [
			EventItem(
				id: '1',
				title: 'Festival des Arts',
				place: 'Place du Ralliement',
				date: DateTime.now().add(const Duration(days: 10)),
			),
			EventItem(
				id: '2',
				title: 'Concert Jazz',
				place: 'Théâtre',
				date: DateTime.now().add(const Duration(days: 4)),
			),
			EventItem(
				id: '3',
				title: 'Conférence Tech',
				place: 'Université',
				date: DateTime.now().add(const Duration(days: 20)),
			),
			EventItem(
				id: '4',
				title: 'Marché Nocturne',
				place: 'Quai',
				date: DateTime.now().add(const Duration(days: 2)),
			),
		];

		// Keep only future events and sort by date
		_allEvents = _allEvents.where((e) => e.date.isAfter(DateTime.now())).toList()
			..sort((a, b) => a.date.compareTo(b.date));

		_filteredEvents = List.from(_allEvents);

		_searchController.addListener(_onSearchChanged);
	}

	@override
	void dispose() {
		_searchController.removeListener(_onSearchChanged);
		_searchController.dispose();
		super.dispose();
	}

	void _onSearchChanged() {
		final q = _searchController.text.trim().toLowerCase();
		setState(() {
			if (q.isEmpty) {
				_filteredEvents = List.from(_allEvents);
			} else {
				_filteredEvents = _allEvents.where((e) {
					return e.title.toLowerCase().contains(q) || e.place.toLowerCase().contains(q);
				}).toList();
			}
		});
	}

	Future<void> _refresh() async {
		// TODO: trigger reload from API/provider
		await Future.delayed(const Duration(milliseconds: 300));
		setState(() {});
	}

	String _formatDate(DateTime d) {
		final local = d.toLocal();
		// Simple formatted date: DD/MM HH:MM
		final two = (int n) => n.toString().padLeft(2, '0');
		return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.getPrimaryBackground(context),
			body: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					children: [
						const SizedBox(height: 48),
						// Search field
						Container(
							decoration: BoxDecoration(
								borderRadius: BorderRadius.circular(12),
								boxShadow: [
									BoxShadow(
										color: AppColors.primaryButton.withOpacity(0.2),
										blurRadius: 12,
										spreadRadius: 0,
										offset: const Offset(0, 2),
									),
									BoxShadow(
										color: AppColors.secondaryText.withOpacity(0.15),
										blurRadius: 8,
										spreadRadius: 0,
										offset: const Offset(0, 1),
									),
								],
							),
							child: TextField(
								controller: _searchController,
								style: TextStyle(color: AppColors.getTextPrimary(context)),
								decoration: InputDecoration(
									hintText: 'Rechercher un événement ou un lieu',
									hintStyle: TextStyle(color: AppColors.getTextDisabled(context)),
									prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
									filled: true,
									fillColor: AppColors.getCardBackground(context),
									border: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: BorderSide(
											color: AppColors.primaryButton.withOpacity(0.3),
											width: 1,
										),
									),
									enabledBorder: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: BorderSide(
											color: AppColors.primaryButton.withOpacity(0.2),
											width: 1,
										),
									),
									focusedBorder: OutlineInputBorder(
										borderRadius: BorderRadius.circular(12),
										borderSide: BorderSide(
											color: AppColors.primaryButton.withOpacity(0.5),
											width: 1.5,
										),
									),
								),
							),
						),
						const SizedBox(height: 24),

						// Header + count
						Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								const Text(
									'Prochains événements',
									style: TextStyle(
										fontSize: 16,
										fontWeight: FontWeight.bold,
										color: AppColors.primaryButton,
									),
								),
								Text(
									'${_filteredEvents.length} trouvés',
									style: const TextStyle(
										color: AppColors.secondaryText,
									),
								),
							],
						),
						const SizedBox(height: 8),

						// List
						Expanded(
							child: RefreshIndicator(
								onRefresh: _refresh,
								color: AppColors.primaryButton,
								child: _filteredEvents.isEmpty
										? ListView(
												physics: const AlwaysScrollableScrollPhysics(),
												padding: const EdgeInsets.only(bottom: 100),
												children: [
													SizedBox(
														height: MediaQuery.of(context).size.height * 0.5,
														child: Center(
															child: Text(
																_searchController.text.isEmpty
																		? 'Aucun événement à venir.'
																		: 'Aucun résultat pour "${_searchController.text}"',
																style: TextStyle(
																	color: AppColors.getTextPrimary(context),
																),
															),
														),
													),
												],
											)
										: ListView.separated(
												padding: const EdgeInsets.only(bottom: 100),
												itemCount: _filteredEvents.length,
												separatorBuilder: (_, __) => const SizedBox(height: 8),
												itemBuilder: (context, index) {
													final ev = _filteredEvents[index];
													return InkWell(
														onTap: () {
															Navigator.push(
																context,
																MaterialPageRoute(
																	builder: (context) => EventDetailsScreen(event: ev),
																),
															);
														},
														child: Container(
															padding: const EdgeInsets.all(12),
															decoration: BoxDecoration(
																color: AppColors.getCardBackground(context),
																borderRadius: BorderRadius.circular(10),
															),
															child: Row(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																// Left: date badge
																Container(
																	padding: const EdgeInsets.all(8),
																	decoration: BoxDecoration(
																		color: AppColors.primaryButton.withOpacity(0.2),
																		borderRadius: BorderRadius.circular(8),
																	),
																	child: Column(
																		mainAxisSize: MainAxisSize.min,
																		children: [
																			Text(
																				'${ev.date.day}',
																				style: const TextStyle(
																					fontSize: 18,
																					fontWeight: FontWeight.bold,
																					color: AppColors.primaryButton,
																				),
																			),
																			Text(
																				'${ev.date.month}',
																				style: const TextStyle(
																					color: AppColors.secondaryText,
																				),
																			),
																		],
																	),
																),
																const SizedBox(width: 12),
																// Middle: details
																Expanded(
																	child: Column(
																		crossAxisAlignment: CrossAxisAlignment.start,
																		children: [
																			Text(
																				ev.title,
																				style: TextStyle(
																					fontSize: 16,
																					fontWeight: FontWeight.w600,
																					color: AppColors.getTextPrimary(context),
																				),
																			),
																			const SizedBox(height: 6),
																			Text(
																				ev.place,
																				style: const TextStyle(
																					color: AppColors.secondaryText,
																				),
																			),
																		],
																	),
																),
																// Right: time & action
																Column(
																	crossAxisAlignment: CrossAxisAlignment.end,
																	children: [
																		Text(
																			_formatDate(ev.date),
																			style: TextStyle(
																				color: AppColors.getTextPrimary(context),
																			),
																		),
																		const SizedBox(height: 8),
																		IconButton(
																			onPressed: () {
																				// TODO: toggle favorite or open details
																			},
																			icon: const Icon(
																				Icons.star_border,
																				color: AppColors.primaryButton,
																			),
																		),
																	],
																),
															],
														),
													),
													);
												},
											),
							),
						),
					],
				),
			),
		);
	}
}
