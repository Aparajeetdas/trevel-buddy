/// Data models for the Scam Playbook and Hotspots Area Risk intelligence
class ScamPlaybookEntry {
  final String id;
  final String title;
  final String category;
  final String howItWorks;
  final List<String> redFlags;
  final String whatToSay;
  final String whatToDo;
  final String typicalExtraCost;
  final String severity; // Low, Medium, High

  const ScamPlaybookEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.howItWorks,
    required this.redFlags,
    required this.whatToSay,
    required this.whatToDo,
    required this.typicalExtraCost,
    this.severity = 'Medium',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'howItWorks': howItWorks,
    'redFlags': redFlags,
    'whatToSay': whatToSay,
    'whatToDo': whatToDo,
    'typicalExtraCost': typicalExtraCost,
    'severity': severity,
  };

  factory ScamPlaybookEntry.fromJson(Map<String, dynamic> json) =>
      ScamPlaybookEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        howItWorks: json['howItWorks'] as String,
        redFlags: (json['redFlags'] as List<dynamic>)
            .map((e) => e.toString())
            .toList(),
        whatToSay: json['whatToSay'] as String,
        whatToDo: json['whatToDo'] as String,
        typicalExtraCost: json['typicalExtraCost'] as String,
        severity: json['severity'] as String? ?? 'Medium',
      );

  /// 10 seeded standard scam playbooks covering transport, guides, shops, hotels & entry tickets
  static const List<ScamPlaybookEntry> seededPlaybook = [
    ScamPlaybookEntry(
      id: 'pb-01',
      title: 'Broken Meter / Refusal to Run Meter',
      category: 'Transport',
      howItWorks: 'Driver claims meter is broken, disconnected, or quotes an inflated flat rate 3x to 5x higher than legal rates.',
      redFlags: [
        'Meter is covered by cloth, phone, or unplugged',
        'Claims meter applies only to locals',
        'Quotes exorbitant fixed rate before you sit',
      ],
      whatToSay: '"Bhaiya meter chalao, ya fir hum doosri auto le rahe hain." (Please turn on the meter, or we will take another auto).',
      whatToDo: 'Always insist on meter before entering. If driver refuses, walk to the next auto or use official prepaid booth.',
      typicalExtraCost: '₹150 - ₹400 over legal fare',
      severity: 'Medium',
    ),
    ScamPlaybookEntry(
      id: 'pb-02',
      title: '"Hotel / Monument is Closed Today"',
      category: 'Diversion',
      howItWorks: 'Driver or tout falsely claims your booked hotel is closed, burned down, or in a blocked festival zone to divert you to their commission hotel.',
      redFlags: [
        'Insists your accommodation is unavailable',
        'Offers to take you to a "much better, cheaper tourist center"',
        'Fakes a phone call to pretend the road is blocked',
      ],
      whatToSay: '"Maine hotel se 5 minute pehle baat ki hai, woh open hai. Mujhe wahi le chalo." (I spoke to the hotel 5 minutes ago, it is open. Take me there).',
      whatToDo: 'Call your hotel directly using the number in your original confirmation email. Never rely on the driver\'s phone.',
      typicalExtraCost: '₹1,500 - ₹5,000 per night inflated tariff',
      severity: 'High',
    ),
    ScamPlaybookEntry(
      id: 'pb-03',
      title: 'Emporium & Gemstone Commission Diversion',
      category: 'Shopping',
      howItWorks: 'Driver offers very cheap city tour (e.g. ₹200 for full day), then forces stops at high-pressure textile/gemstone emporiums where they earn 30-50% cut.',
      redFlags: [
        'Driver offers unusually cheap tour package',
        'Repeatedly stops at "government approved" handicraft shops',
        'Says stopping for 10 minutes gives him petrol vouchers',
      ],
      whatToSay: '"Hum shopping nahi karenge. Kripya direct monument chaliye." (We do not want to shop. Please take us directly to the monument).',
      whatToDo: 'Agree beforehand: "No shopping stops". If taken inside, politely decline and remain near the entrance.',
      typicalExtraCost: '300% - 1000% markup on synthetic gems & fabrics',
      severity: 'High',
    ),
    ScamPlaybookEntry(
      id: 'pb-04',
      title: 'Unauthorized "Official" Heritage Guide',
      category: 'Sightseeing',
      howItWorks: 'Touts outside fort entrances wear fake laminated ID tags and claim to be government guides, demanding ₹1,500+ for brief, inaccurate walk-throughs.',
      redFlags: [
        'Approaches aggressively in parking lots or ticket queues',
        'ID lacks official Ministry of Tourism holographic badge',
        'Demands upfront cash before showing tickets',
      ],
      whatToSay: '"Kripya apna official Ministry of Tourism licence dikhaiye." (Please show your official Ministry license).',
      whatToDo: 'Only hire guides from the official Archaeological Survey of India (ASI) or State Tourism booth inside the gate at fixed rate slips.',
      typicalExtraCost: '₹700 - ₹1,500 above notified guide fee',
      severity: 'Medium',
    ),
    ScamPlaybookEntry(
      id: 'pb-05',
      title: 'End of Ride Surprise Surcharges',
      category: 'Transport',
      howItWorks: 'At the destination, driver demands extra ₹200 for "luggage fee", "AC charge", "inter-state toll", or "waiting in red lights".',
      redFlags: [
        'Didn\'t mention extra charges at the start',
        'Refuses to return change from a large banknote',
        'Claims toll charges without showing fastag receipt',
      ],
      whatToSay: '"Jo fare pehle tay hua tha, wahi final hai. Extra charges nahi." (The fare agreed at pickup is final. No unexpected charges).',
      whatToDo: 'Pay exact agreed amount via UPI/cash. Walk into a populated hotel lobby or security gate if intimidation occurs.',
      typicalExtraCost: '₹100 - ₹300 per trip',
      severity: 'Medium',
    ),
    ScamPlaybookEntry(
      id: 'pb-06',
      title: 'Tuk-Tuk Night Surcharge Extortion',
      category: 'Transport',
      howItWorks: 'Driver charges 100% - 200% extra citing "night charge", whereas the legal state surcharge is only 25% between 11 PM and 5 AM.',
      redFlags: [
        'Claims night surcharge starts at 8 PM or 9 PM',
        'Demands double the daytime fare',
      ],
      whatToSay: '"RTA niyamon ke anusar night charges sirf 25% hain aur raat 11 baje ke baad lagte hain." (By law night charge is only 25% after 11 PM).',
      whatToDo: 'Reference Travel Buddy\'s official tariff counter-offer. Check the clock before boarding.',
      typicalExtraCost: '₹150 - ₹500 extra',
      severity: 'Medium',
    ),
    ScamPlaybookEntry(
      id: 'pb-07',
      title: 'Fake Front-of-Line / VIP Temple Pass',
      category: 'Tickets',
      howItWorks: 'Touts claim standard queue is 4 hours and offer "VIP direct darshan" tickets for ₹500 - ₹2,000, which are fake or standard free entry.',
      redFlags: [
        'Unofficial sellers wandering outside temple gates',
        'Handwritten paper slips without temple trust stamps',
        'Pressure to act fast before "doors close"',
      ],
      whatToSay: '"Hum official temple counter se hi ticket lenge." (We will purchase tickets only from the official temple counter).',
      whatToDo: 'Proceed directly to the official temple trust counter or check the temple trust website for special darshan booking.',
      typicalExtraCost: '₹500 - ₹2,000 per person',
      severity: 'High',
    ),
    ScamPlaybookEntry(
      id: 'pb-08',
      title: 'Special "Royal" Spice & Tea Boutique',
      category: 'Shopping',
      howItWorks: 'Tourists are led to specialty spice shops claiming saffron or Ayurvedic tea cures, selling ordinary or adulterated goods at 10x European prices.',
      redFlags: [
        'Free tea tastings accompanied by emotional sales stories',
        'Claims saffron is from exclusive royal plantations',
        'Prices quoted in EUR or USD rather than INR',
      ],
      whatToSay: '"Shukriya, par hume abhi nahi kharidna." (Thank you, but we do not wish to purchase right now).',
      whatToDo: 'Buy spices and teas from standard local supermarkets (e.g. Reliance, D-Mart) or certified Khadi Gramodyog stores.',
      typicalExtraCost: '₹1,000 - ₹8,000',
      severity: 'Medium',
    ),
    ScamPlaybookEntry(
      id: 'pb-09',
      title: 'Unsolicited Shoe Polishing / Foot Staining',
      category: 'Street Tout',
      howItWorks: 'Tout squirts grime onto your shoes or feet when you aren\'t looking, then quickly offers an "emergency cleaning" demanding ₹300 - ₹1,000.',
      redFlags: [
        'Someone taps your foot or points down urgently',
        'Puck-sized cleaner appeared instantly without calling',
      ],
      whatToSay: '"Nahi chahiye, door rahiye." (Not needed, please keep away).',
      whatToDo: 'Keep walking firmly without stopping. Clean your shoe yourself inside your hotel or a convenience store restroom.',
      typicalExtraCost: '₹200 - ₹500',
      severity: 'Low',
    ),
    ScamPlaybookEntry(
      id: 'pb-10',
      title: 'Airport & Train Station Fake Prepaid Taxi Touts',
      category: 'Transport',
      howItWorks: 'Touts stand outside arrival halls waving clipboard forms claiming to be the "Prepaid Booth", leading you to unlicensed private cars.',
      redFlags: [
        'Tout approaches you instead of you approaching a fixed window booth',
        'Payment demanded in cash directly to the driver before getting in',
        'No computerized receipt with vehicle registration number',
      ],
      whatToSay: '"Hum traffic police ke official prepaid counter par jayenge." (We will go to the Traffic Police official counter).',
      whatToDo: 'Follow physical airport/station signs to the official Traffic Police Prepaid Booth inside the terminal and collect a printed slip.',
      typicalExtraCost: '₹300 - ₹800 over official prepaid tariff',
      severity: 'High',
    ),
  ];
}

/// Area Risk intelligence model calculated for hotspot zones
class AreaRisk {
  final String areaId;
  final String areaName;
  final String city;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final double complaintScore;
  final double priceIndexScore;
  final double severityScore;
  final double
  areaRiskScore; // 0.5 * complaint + 0.3 * priceIndex + 0.2 * severity
  final String riskLevel; // Low (<35), Medium (35-65), High (>65)
  final String trend; // 'rising', 'stable', 'falling'
  final List<String> topScamTypes;
  final int totalReportsCount;
  final String whyThisScore;

  const AreaRisk({
    required this.areaId,
    required this.areaName,
    required this.city,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.complaintScore,
    required this.priceIndexScore,
    required this.severityScore,
    required this.areaRiskScore,
    required this.riskLevel,
    required this.trend,
    required this.topScamTypes,
    required this.totalReportsCount,
    required this.whyThisScore,
  });

  Map<String, dynamic> toJson() => {
    'areaId': areaId,
    'areaName': areaName,
    'city': city,
    'centerLat': centerLat,
    'centerLng': centerLng,
    'radiusMeters': radiusMeters,
    'complaintScore': complaintScore,
    'priceIndexScore': priceIndexScore,
    'severityScore': severityScore,
    'areaRiskScore': areaRiskScore,
    'riskLevel': riskLevel,
    'trend': trend,
    'topScamTypes': topScamTypes,
    'totalReportsCount': totalReportsCount,
    'whyThisScore': whyThisScore,
  };

  factory AreaRisk.fromJson(Map<String, dynamic> json) => AreaRisk(
    areaId: json['areaId'] as String,
    areaName: json['areaName'] as String,
    city: json['city'] as String,
    centerLat: (json['centerLat'] as num).toDouble(),
    centerLng: (json['centerLng'] as num).toDouble(),
    radiusMeters: (json['radiusMeters'] as num).toDouble(),
    complaintScore: (json['complaintScore'] as num).toDouble(),
    priceIndexScore: (json['priceIndexScore'] as num).toDouble(),
    severityScore: (json['severityScore'] as num).toDouble(),
    areaRiskScore: (json['areaRiskScore'] as num).toDouble(),
    riskLevel: json['riskLevel'] as String,
    trend: json['trend'] as String? ?? 'stable',
    topScamTypes: (json['topScamTypes'] as List<dynamic>)
        .map((e) => e.toString())
        .toList(),
    totalReportsCount: json['totalReportsCount'] as int,
    whyThisScore: json['whyThisScore'] as String,
  );
}
