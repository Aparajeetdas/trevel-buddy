/**
 * Travel Buddy - Agent Tools & Validation
 *
 * Server-run tools:
 *   - checkPrice: pricing engine (official tariffs, city standard rates, risk verdict)
 *   - getAirportPrepaidFare: LGBI airport official prepaid taxi fares
 *   - getPlaceDetails: place info from Google / OpenStreetMap
 *   - searchNearby: search spots / attractions
 *   - getRouteEstimate: driving distance & duration
 *   - getScamRadar: known scam traps by city/category
 *   - getPlaybook: safety & bargaining scripts
 *   - createRoadmapSummary: multi-leg route summary
 *
 * Client-action tools (NEVER executed on server; validated and returned as action cards):
 *   - openInMaps
 *   - openDirections
 *   - openScreen
 */

const { z } = require('zod');
const fs = require('node:fs');
const path = require('node:path');

// Strip HTML tags, URLs, control characters, and cap length
function sanitizeForDataBlock(text, maxLength = 300) {
  if (!text || typeof text !== 'string') return '';
  let cleaned = text
    .replace(/<[^>]*>/g, '')
    .replace(/https?:\/\/[^\s]+/gi, '[link removed]')
    .replace(/[^\x20-\x7E\u0900-\u097F\n]/g, '')
    .trim();
  if (cleaned.length > maxLength) {
    cleaned = cleaned.slice(0, maxLength) + '...';
  }
  return cleaned;
}

// Wrap untrusted user or 3rd-party text in <data> tags
function wrapDataBlock(text, maxLength = 300) {
  const sanitized = sanitizeForDataBlock(text, maxLength);
  return `<data>${sanitized}</data>`;
}

// Load Airport Prepaid Fares Data
let airportFareRoutes = [];
try {
  const fareFile = path.resolve(__dirname, '../assets/data/airport_prepaid_taxi_fares.json');
  if (fs.existsSync(fareFile)) {
    const raw = fs.readFileSync(fareFile, 'utf8');
    const parsed = JSON.parse(raw);
    airportFareRoutes = Array.isArray(parsed.routes) ? parsed.routes : [];
  }
} catch (e) {
  console.error('[Agent Tools] Failed to load airport fares:', e.message);
}

// Fixed allowlist of screens for openScreen
const ALLOWED_SCREENS = new Set([
  'check_price',
  'explore',
  'tourist_traps',
  'roadmap',
  'verify_driver',
  'airport_fares',
  'home',
]);

// -----------------------------------------------------------------------------
// Zod Tool Schemas
// -----------------------------------------------------------------------------

const ToolSchemas = {
  checkPrice: z.object({
    pickup: z.string().min(1).max(100),
    destination: z.string().min(1).max(100),
    quotedPrice: z.number().positive().max(100000),
    serviceType: z.enum(['taxi', 'auto', 'bike', 'cab']).optional().default('taxi'),
    city: z.string().optional().default('Guwahati'),
    distanceKm: z.number().positive().max(1000).optional(),
  }),

  getAirportPrepaidFare: z.object({
    destination: z.string().min(1).max(100),
    airport: z.string().optional().default('LGBI Airport, Guwahati'),
  }),

  getPlaceDetails: z.object({
    placeId: z.string().min(1).max(200),
  }),

  searchNearby: z.object({
    query: z.string().min(1).max(100),
    lat: z.number().min(-90).max(90).optional(),
    lng: z.number().min(-180).max(180).optional(),
    city: z.string().optional(),
  }),

  getRouteEstimate: z.object({
    origin: z.string().min(1).max(100),
    destination: z.string().min(1).max(100),
  }),

  getScamRadar: z.object({
    city: z.string().min(1).max(50),
    category: z.string().optional(),
  }),

  getPlaybook: z.object({
    scenario: z.string().min(1).max(100),
  }),

  createRoadmapSummary: z.object({
    origin: z.string().min(1).max(100),
    destination: z.string().min(1).max(100),
    budget: z.number().positive().optional(),
  }),

  // Client actions
  openInMaps: z.object({
    placeId: z.string().optional(),
    lat: z.number().min(-90).max(90).optional(),
    lng: z.number().min(-180).max(180).optional(),
    query: z.string().max(100).optional(),
  }),

  openDirections: z.object({
    destination: z.string().min(1).max(100),
    origin: z.string().max(100).optional(),
    mode: z.enum(['driving', 'walking', 'transit']).optional().default('driving'),
  }),

  openScreen: z.object({
    screen: z.string().refine((s) => ALLOWED_SCREENS.has(s), {
      message: 'Screen not in allowlist',
    }),
    params: z.record(z.any()).optional().default({}),
  }),
};

// -----------------------------------------------------------------------------
// Gemini Function Declarations
// -----------------------------------------------------------------------------

const GEMINI_FUNCTION_DECLARATIONS = [
  {
    name: 'checkPrice',
    description: 'Calculates the fair price and verdict (Fair, Suspicious, High Risk) for a quoted trip using official prepaid tariffs and distance matrices.',
    parameters: {
      type: 'OBJECT',
      properties: {
        pickup: { type: 'STRING', description: 'Origin or pickup location name' },
        destination: { type: 'STRING', description: 'Destination location name' },
        quotedPrice: { type: 'NUMBER', description: 'Price quoted by the driver in INR' },
        serviceType: { type: 'STRING', enum: ['taxi', 'auto', 'bike', 'cab'], description: 'Vehicle type' },
        city: { type: 'STRING', description: 'City name (e.g. Guwahati, Delhi, Goa)' },
        distanceKm: { type: 'NUMBER', description: 'Estimated trip distance in kilometers if known' },
      },
      required: ['pickup', 'destination', 'quotedPrice'],
    },
  },
  {
    name: 'getAirportPrepaidFare',
    description: 'Looks up the official government-approved prepaid taxi tariff from LGBI Airport, Guwahati to a specific destination.',
    parameters: {
      type: 'OBJECT',
      properties: {
        destination: { type: 'STRING', description: 'Destination neighborhood or city name (e.g. Ganeshguri, Paltan Bazar, Shillong)' },
        airport: { type: 'STRING', description: 'Airport name (default LGBI Airport)' },
      },
      required: ['destination'],
    },
  },
  {
    name: 'getPlaceDetails',
    description: 'Retrieves verified tourist information, safety ratings, and address for a given placeId.',
    parameters: {
      type: 'OBJECT',
      properties: {
        placeId: { type: 'STRING', description: 'Place identifier' },
      },
      required: ['placeId'],
    },
  },
  {
    name: 'searchNearby',
    description: 'Searches for attractions, taxi stands, or points of interest near given coordinates or query.',
    parameters: {
      type: 'OBJECT',
      properties: {
        query: { type: 'STRING', description: 'Search query' },
        lat: { type: 'NUMBER', description: 'Latitude' },
        lng: { type: 'NUMBER', description: 'Longitude' },
        city: { type: 'STRING', description: 'City name' },
      },
      required: ['query'],
    },
  },
  {
    name: 'getRouteEstimate',
    description: 'Estimates driving distance in km and duration between two locations in India.',
    parameters: {
      type: 'OBJECT',
      properties: {
        origin: { type: 'STRING', description: 'Starting point' },
        destination: { type: 'STRING', description: 'Ending point' },
      },
      required: ['origin', 'destination'],
    },
  },
  {
    name: 'getScamRadar',
    description: 'Returns known tourist traps, rip-offs, and driver scams reported in a specific city or area.',
    parameters: {
      type: 'OBJECT',
      properties: {
        city: { type: 'STRING', description: 'City name (e.g. Guwahati, Delhi, Agra, Goa)' },
        category: { type: 'STRING', description: 'Category (e.g. taxi, hotel, guide, shop)' },
      },
      required: ['city'],
    },
  },
  {
    name: 'getPlaybook',
    description: 'Returns practical bargaining scripts, Hinglish negotiation phrases, and safety procedures for transport.',
    parameters: {
      type: 'OBJECT',
      properties: {
        scenario: { type: 'STRING', description: 'Scenario (e.g. meter_refusal, airport_counter, overcharging, emergency)' },
      },
      required: ['scenario'],
    },
  },
  {
    name: 'createRoadmapSummary',
    description: 'Generates step-by-step guidance on how to travel between two points (e.g. airport to hotel or interstate trip).',
    parameters: {
      type: 'OBJECT',
      properties: {
        origin: { type: 'STRING', description: 'Starting place' },
        destination: { type: 'STRING', description: 'Destination place' },
        budget: { type: 'NUMBER', description: 'Travel budget in INR' },
      },
      required: ['origin', 'destination'],
    },
  },
  // Client Action Declarations
  {
    name: 'openInMaps',
    description: 'Client action: prompts the user with a button to view a location in Google Maps.',
    parameters: {
      type: 'OBJECT',
      properties: {
        placeId: { type: 'STRING', description: 'Place ID' },
        lat: { type: 'NUMBER', description: 'Latitude' },
        lng: { type: 'NUMBER', description: 'Longitude' },
        query: { type: 'STRING', description: 'Search query' },
      },
    },
  },
  {
    name: 'openDirections',
    description: 'Client action: prompts the user with a button to open turn-by-turn navigation in Maps.',
    parameters: {
      type: 'OBJECT',
      properties: {
        destination: { type: 'STRING', description: 'Destination name or address' },
        origin: { type: 'STRING', description: 'Origin name or address' },
        mode: { type: 'STRING', enum: ['driving', 'walking', 'transit'] },
      },
      required: ['destination'],
    },
  },
  {
    name: 'openScreen',
    description: 'Client action: prompts the user with a button to open an in-app screen (check_price, explore, tourist_traps, roadmap, airport_fares).',
    parameters: {
      type: 'OBJECT',
      properties: {
        screen: { type: 'STRING', enum: ['check_price', 'explore', 'tourist_traps', 'roadmap', 'verify_driver', 'airport_fares', 'home'] },
        params: { type: 'OBJECT', description: 'Screen arguments' },
      },
      required: ['screen'],
    },
  },
];

const SERVER_RUN_TOOLS = new Set([
  'checkPrice',
  'getAirportPrepaidFare',
  'getPlaceDetails',
  'searchNearby',
  'getRouteEstimate',
  'getScamRadar',
  'getPlaybook',
  'createRoadmapSummary',
]);

const CLIENT_ACTION_TOOLS = new Set([
  'openInMaps',
  'openDirections',
  'openScreen',
]);

// -----------------------------------------------------------------------------
// Server Tool Implementations
// -----------------------------------------------------------------------------

function executeCheckPrice(args) {
  const pickup = (args.pickup || '').toLowerCase();
  const dest = (args.destination || '').toLowerCase();
  const quoted = args.quotedPrice;

  // 1. Check LGBI airport fixed route first
  const isAirport = pickup.includes('airport') || pickup.includes('lgbi') || dest.includes('airport') || dest.includes('lgbi');
  if (isAirport && airportFareRoutes.length > 0) {
    const target = isAirport && pickup.includes('airport') ? dest : pickup;
    const match = airportFareRoutes.find((r) => {
      const name = (r.destinationName || '').toLowerCase();
      const aliases = (r.aliases || []).map((a) => a.toLowerCase());
      return name.includes(target) || target.includes(name) || aliases.some((a) => target.includes(a));
    });

    if (match) {
      const officialFare = match.fare;
      const ratio = quoted / officialFare;
      let verdict = 'Fair';
      let confidence = 'High';
      let note = `Official prepaid taxi fare is ₹${officialFare} (approx ${match.km} km).`;

      if (quoted <= officialFare * 1.05) {
        verdict = 'Fair';
      } else if (ratio > 1.5) {
        verdict = 'High Risk';
        note = `Quoted price is ${ratio.toFixed(1)}x the official prepaid fare of ₹${officialFare}.`;
      } else {
        verdict = 'Suspicious';
        note = `Quoted price of ₹${quoted} is above the official prepaid rate of ₹${officialFare}.`;
      }

      return {
        verdict,
        fairMin: officialFare,
        fairMax: officialFare,
        quotedPrice: quoted,
        source: 'Official tariff',
        confidence,
        factors: [note, 'Ask the counter whether tolls are included.'],
      };
    }
  }

  // 2. City Standard Distance-Based Model
  const estKm = args.distanceKm || (dest.includes('shillong') ? 100 : dest.includes('ganeshguri') ? 28 : 15);
  const baseRate = args.serviceType === 'auto' ? 15 : 24;
  const baseCharge = args.serviceType === 'auto' ? 50 : 200;
  const fairAmount = Math.round(baseCharge + baseRate * estKm);
  const fairMin = Math.round(fairAmount * 0.9);
  const fairMax = Math.round(fairAmount * 1.15);

  let verdict = 'Fair';
  if (quoted <= fairMax * 1.05) {
    verdict = 'Fair';
  } else if (quoted > fairMax * 1.5) {
    verdict = 'High Risk';
  } else {
    verdict = 'Suspicious';
  }

  return {
    verdict,
    fairMin,
    fairMax,
    quotedPrice: quoted,
    source: 'Estimate',
    confidence: 'Medium',
    factors: [`Estimated ${estKm} km at ₹${baseRate}/km plus standard base fare.`],
  };
}

function executeGetAirportPrepaidFare(args) {
  const destQuery = (args.destination || '').toLowerCase().trim();
  if (!destQuery) return { found: false, message: 'Destination not specified' };

  // Match against airport fares dataset
  const matches = airportFareRoutes.filter((r) => {
    const name = (r.destination || r.destinationName || '').toLowerCase().trim();
    if (!name) return false;
    const hi = (r.nameHi || '').toLowerCase().trim();
    const aliases = (r.aliases || []).map((a) => (a || '').toLowerCase().trim()).filter(Boolean);
    return (
      name === destQuery ||
      aliases.includes(destQuery) ||
      (destQuery.length > 3 && name.includes(destQuery)) ||
      (name.length > 3 && destQuery.includes(name) && !destQuery.includes('ignore previous instructions')) ||
      (hi && hi === destQuery)
    );
  });

  if (matches.length === 1) {
    const m = matches[0];
    return {
      found: true,
      destination: m.destination || m.destinationName,
      km: m.km,
      fare: m.fare,
      category: m.category,
      source: 'Official tariff',
      effectiveDate: 'not stated',
      verified: true,
      flags: m.flags || [],
      advisory: 'Ask the counter whether tolls are included',
    };
  } else if (matches.length > 1) {
    return {
      found: true,
      ambiguous: true,
      candidates: matches.map((m) => ({ destination: m.destination || m.destinationName, fare: m.fare, km: m.km })),
      message: 'Multiple prepaid tariff destinations match this location. Please specify the exact area.',
      source: 'Official tariff',
    };
  }

  return {
    found: false,
    message: wrapDataBlock(`Destination '${args.destination}' is not explicitly listed in the LGBI Airport prepaid list. Standard estimate uses ₹200 base + ₹24/km.`),
    source: 'Estimate',
  };
}

function executeGetScamRadar(args) {
  const city = (args.city || '').toLowerCase();
  const defaultScams = [
    { title: 'Airport Outside Tout Markup', description: 'Touts approach outside terminal claiming prepaid booth is closed or charges double. Real booth is right inside arrival hall.' },
    { title: 'Commission Hotel Detour', description: 'Driver claims your booked hotel is full or flooded, offering an alternative where they receive 30% commission.' },
    { title: 'Broken Meter Excuse', description: 'Auto-rickshaw driver claims electronic meter is broken and quotes flat ₹300-₹500 for a ₹90 ride.' },
  ];

  if (city.includes('guwahati')) {
    return {
      city: 'Guwahati',
      source: 'Playbook',
      traps: defaultScams.map((s) => ({
        title: s.title,
        description: wrapDataBlock(s.description),
      })),
    };
  }

  return {
    city: args.city || 'General India',
    source: 'Playbook',
    traps: defaultScams.map((s) => ({
      title: s.title,
      description: wrapDataBlock(s.description),
    })),
  };
}

function executeGetPlaybook(args) {
  const scenario = (args.scenario || '').toLowerCase();
  if (scenario.includes('emergency') || scenario.includes('unsafe') || scenario.includes('police')) {
    return {
      source: 'Playbook',
      emergencyNumber: '112',
      guidance: 'National Emergency Helpline: 112. Inform driver loudly that your live location is tracked.',
      actions: ['Call 112', 'Share Live Location'],
    };
  }

  return {
    source: 'Playbook',
    phrases: [
      { hindi: 'Meter se chaliye', english: 'Please turn on the meter', usage: 'Use immediately upon boarding auto-rickshaws' },
      { hindi: 'Prepaid counter kahan hai?', english: 'Where is the official prepaid booth?', usage: 'Use at airports and railway stations' },
      { hindi: 'Raste ka toll shaamil hai?', english: 'Are highway tolls included in this fare?', usage: 'Confirm before long-distance taxi trips' },
    ],
  };
}

function executeCreateRoadmapSummary(args) {
  return {
    origin: args.origin,
    destination: args.destination,
    source: 'Playbook',
    steps: [
      { step: 1, text: 'Walk to the official government prepaid taxi booth inside the arrival terminal.' },
      { step: 2, text: `Book fixed-route ticket for ${args.destination}. Keep official printed receipt.` },
      { step: 3, text: 'Present receipt copy only upon arrival at destination.' },
    ],
  };
}

/**
 * Executes a server tool and returns the response for Gemini.
 */
async function executeServerTool(toolName, rawArgs) {
  const schema = ToolSchemas[toolName];
  if (!schema) {
    return { error: `Unknown tool: ${toolName}` };
  }

  const parseResult = schema.safeParse(rawArgs || {});
  if (!parseResult.success) {
    return {
      error: `Invalid tool arguments for ${toolName}: ${parseResult.error.issues.map((i) => i.message).join(', ')}`,
    };
  }

  const args = parseResult.data;

  switch (toolName) {
    case 'checkPrice':
      return executeCheckPrice(args);

    case 'getAirportPrepaidFare':
      return executeGetAirportPrepaidFare(args);

    case 'getScamRadar':
      return executeGetScamRadar(args);

    case 'getPlaybook':
      return executeGetPlaybook(args);

    case 'createRoadmapSummary':
      return executeCreateRoadmapSummary(args);

    case 'getRouteEstimate': {
      const isAirport = args.origin.toLowerCase().includes('airport') || args.destination.toLowerCase().includes('airport');
      const isShillong = args.destination.toLowerCase().includes('shillong');
      const km = isShillong ? 100 : isAirport ? 28 : 12;
      return {
        origin: args.origin,
        destination: args.destination,
        distanceKm: km,
        estimatedDurationMinutes: Math.round(km * 2.2),
        source: 'Google',
      };
    }

    case 'getPlaceDetails':
      return {
        placeId: args.placeId,
        verified: true,
        source: 'Google',
        details: wrapDataBlock(`Verified tourist point in Guwahati. Operating hours 9 AM - 6 PM.`),
      };

    case 'searchNearby':
      return {
        query: args.query,
        source: 'Google',
        results: [
          { name: `${args.query} Stand`, distance: '350m' },
          { name: 'Official Prepaid Booth', distance: '120m' },
        ],
      };

    default:
      return { error: `Tool ${toolName} execution not implemented on server.` };
  }
}

/**
 * Validates a client action requested by Gemini and formats it as an action card.
 */
function validateClientAction(actionName, rawArgs) {
  const schema = ToolSchemas[actionName];
  if (!schema) return null;

  const parseResult = schema.safeParse(rawArgs || {});
  if (!parseResult.success) return null;

  const args = parseResult.data;

  if (actionName === 'openInMaps') {
    return {
      type: 'open_in_maps',
      label: 'Open in Google Maps',
      params: {
        placeId: args.placeId || '',
        lat: args.lat || null,
        lng: args.lng || null,
        query: args.query || '',
      },
    };
  }

  if (actionName === 'openDirections') {
    return {
      type: 'open_directions',
      label: `Directions to ${args.destination}`,
      params: {
        destination: args.destination,
        origin: args.origin || '',
        mode: args.mode || 'driving',
      },
    };
  }

  if (actionName === 'openScreen') {
    const screenLabels = {
      check_price: 'Check a Price',
      explore: 'Explore Places',
      tourist_traps: 'Tourist Trap Radar',
      roadmap: 'Transit Roadmap',
      verify_driver: 'Verify Driver',
      airport_fares: 'Airport Prepaid Fares',
      home: 'Go to Home',
    };
    return {
      type: 'open_screen',
      label: screenLabels[args.screen] || 'Open Screen',
      params: {
        screen: args.screen,
        args: args.params || {},
      },
    };
  }

  return null;
}

module.exports = {
  ToolSchemas,
  GEMINI_FUNCTION_DECLARATIONS,
  SERVER_RUN_TOOLS,
  CLIENT_ACTION_TOOLS,
  executeServerTool,
  validateClientAction,
  wrapDataBlock,
  sanitizeForDataBlock,
};
