import Foundation

enum PaceUnit: String, Codable {
    case minPerKm
    case kmPerHour
}

enum Sport: String, CaseIterable, Identifiable, Codable {
    var id: String { self.rawValue }
    
    // MARK: Important Sports
    case running = "Running"
    case cycling = "Cycling"
    case strengthTraining = "Strength Training"
    case walking = "Walking"
    case indoorCycling = "Indoor Cycling"
    case treadmillRunning = "Treadmill Running"
    case crossTrainer = "Cross-Trainer"
    case swimming = "Swimming"
    case mountainBiking = "Mountain Biking"
    case hiking = "Hiking"
    case jogging = "Jogging"
    case hiit = "HIIT"
    
    // MARK: Other Sports
    case adaptiveWaterSkiing = "Adaptive Water Skiing"
    case aerobics = "Aerobics"
    case aquaFitness = "Aqua Fitness"
    case backcountrySkiing = "Backcountry Skiing"
    case badminton = "Badminton"
    case ballet = "Ballet"
    case ballroom = "Ballroom"
    case baseball = "Baseball"
    case basketball = "Basketball"
    case beachTennis = "Beach Tennis"
    case beachVolleyball = "Beach Volleyball"
    case biathlon = "Biathlon"
    case bodyAndMind = "Body & Mind"
    case bootcamp = "Bootcamp"
    case boxing = "Boxing"
    case canoeing = "Canoeing"
    case carRacing = "Car Racing"
    case circuitTraining = "Circuit Training"
    case classicRollerSkiing = "Classic Roller Skiing"
    case classicXCSkiing = "Classic XC Skiing"
    case climbingIndoor = "Climbing (Indoor)"
    case climbingOutdoor = "Climbing (Outdoor)"
    case core = "Core"
    case cricket = "Cricket"
    case crossCountryRunning = "Cross-Country Running"
    case curling = "Curling"
    case dancing = "Dancing"
    case discGolf = "Disc Golf"
    case dogAgility = "Dog Agility"
    case downhillSkiing = "Downhill Skiing"
    case electricBiking = "Electric Biking"
    case enduro = "Enduro"
    case esports = "Esports"
    case fieldHockey = "Field Hockey"
    case finnishBaseball = "Finnish Baseball"
    case fitnessBoxing = "Fitness Boxing"
    case fitnessDancing = "Fitness Dancing"
    case floorball = "Floorball"
    case football = "Football"
    case freestyleRollerSkiing = "Freestyle Roller Skiing"
    case freestyleXCSkiing = "Freestyle XC Skiing"
    case functionalTraining = "Functional Training"
    case futsal = "Futsal"
    case golf = "Golf"
    case gravelCycling = "Gravel Cycling"
    case groupExercise = "Group Exercise"
    case gymnastics = "Gymnastics"
    case handball = "Handball"
    case handcycling = "Handcycling"
    case hardEnduro = "Hard Enduro"
    case iceHockey = "Ice Hockey"
    case iceSkating = "Ice Skating"
    case indoorRowing = "Indoor Rowing"
    case inlineSkating = "Inline Skating"
    case jazz = "Jazz"
    case judo = "Judo"
    case kayaking = "Kayaking"
    case kettlebell = "Kettlebell"
    case kickbiking = "Kickbiking"
    case kickboxing = "Kickboxing"
    case kitesurfing = "Kitesurfing"
    case latin = "Latin"
    case lesMills = "Les Mills"
    case liss = "LISS"
    case martialArts = "Martial Arts"
    case mobilityDynamic = "Mobility (Dynamic)"
    case mobilityStatic = "Mobility (Static)"
    case modernDance = "Modern Dance"
    case motocross = "Motocross"
    case motorSports = "Motor Sports"
    case mountainBikeOrienteering = "Mountain Bike Orienteering"
    case nordicWalking = "Nordic Walking"
    case norwegianIntervals = "Norwegian Intervals"
    case obstacleCourseRacing = "Obstacle Course Racing"
    case openWaterSwimming = "Open Water Swimming"
    case orienteering = "Orienteering"
    case padel = "Padel"
    case pickleball = "Pickleball"
    case pilates = "Pilates"
    case poolSwimming = "Pool Swimming"
    case riding = "Riding"
    case ringette = "Ringette"
    case roadCycling = "Road Cycling"
    case roadRacing = "Road Racing"
    case roadRunning = "Road Running"
    case rollerSkating = "Roller Skating"
    case ropeSkipping = "Rope Skipping"
    case rowing = "Rowing"
    case rugby = "Rugby"
    case sailing = "Sailing"
    case shootingIndoor = "Shooting (Indoor)"
    case shootingOutdoor = "Shooting (Outdoor)"
    case skateboarding = "Skateboarding"
    case skating = "Skating"
    case skiOrienteering = "Ski Orienteering"
    case skiing = "Skiing"
    case sledHockey = "Sled Hockey"
    case snocross = "Snocross"
    case snowboarding = "Snowboarding"
    case snowshoeTrekking = "Snowshoe Trekking"
    case soccer = "Soccer"
    case spinning = "Spinning"
    case squash = "Squash"
    case stairWorkout = "Stair Workout"
    case stepWorkout = "Step Workout"
    case streetDance = "Street Dance"
    case stretching = "Stretching"
    case sup = "SUP"
    case surfing = "Surfing"
    case tableTennis = "Table Tennis"
    case taekwondo = "Taekwondo"
    case telemarkSkiing = "Telemark Skiing"
    case tennis = "Tennis"
    case trackAndField = "Track & Field"
    case trailRunning = "Trail Running"
    case trotting = "Trotting"
    case ultimate = "Ultimate"
    case ultraRunning = "Ultra Running"
    case volleyball = "Volleyball"
    case wakeboarding = "Wakeboarding"
    case waterRunning = "Water Running"
    case waterSkiing = "Water Skiing"
    case waterSports = "Water Sports"
    case wheelchairBasketball = "Wheelchair Basketball"
    case wheelchairRacing = "Wheelchair Racing"
    case wheelchairTennis = "Wheelchair Tennis"
    case windsurfing = "Windsurfing"
    case yoga = "Yoga"
    
    case otherIndoor = "Other Indoor"
    case otherOutdoor = "Other Outdoor"

    // MARK: Metadata
    
    var useLocation: Bool {
        switch self {
        case .running, .cycling, .walking, .mountainBiking, .hiking, .jogging, .climbingOutdoor,
             .crossCountryRunning, .electricBiking, .gravelCycling, .openWaterSwimming, .orienteering,
             .roadCycling, .roadRunning, .trailRunning, .ultraRunning, .otherOutdoor, .nordicWalking,
             .skiing, .downhillSkiing, .snowboarding, .backcountrySkiing:
            return true
        default:
            return false
        }
    }
    
    var useSpeed: Bool {
        return self.useLocation
    }
    
    var isIndoor: Bool {
        switch self {
        case .indoorCycling, .treadmillRunning, .strengthTraining, .hiit, .yoga, .crossTrainer,
             .aerobics, .ballet, .climbingIndoor, .indoorRowing, .pilates, .spinning, .stairWorkout,
             .otherIndoor, .lesMills:
            return true
        default:
            return !self.useLocation
        }
    }
    
    var typicalPaceUnit: PaceUnit {
        switch self {
        case .running, .walking, .hiking, .jogging, .treadmillRunning, .trailRunning, .ultraRunning, .crossCountryRunning, .nordicWalking:
            return .minPerKm
        default:
            return .kmPerHour
        }
    }

    // MARK: Static Helpers
    static let importantSports: [Sport] = [
        .running, .cycling, .strengthTraining, .walking, .indoorCycling,
        .treadmillRunning, .crossTrainer, .swimming, .mountainBiking,
        .hiking, .jogging, .yoga
    ]
}

// MARK: Icons
extension Sport {
    var icon: String {
        switch self {
        case .cycling, .indoorCycling, .mountainBiking, .electricBiking, .roadCycling, .gravelCycling, .spinning:
            return "figure.outdoor.cycle"
        case .rowing, .indoorRowing:
            return "figure.rower"
        case .strengthTraining, .kettlebell:
            return "dumbbell.fill"
        case .walking, .nordicWalking:
            return "figure.walk"
        case .hiking:
            return "figure.hiking"
        case .yoga, .bodyAndMind, .stretching, .mobilityDynamic, .mobilityStatic:
            return "figure.yoga"
        case .hiit, .liss, .circuitTraining, .functionalTraining, .bootcamp, .norwegianIntervals, .lesMills:
            return "timer"
        case .swimming, .poolSwimming, .openWaterSwimming, .aquaFitness, .waterSports:
            return "figure.pool.swim"
        case .downhillSkiing, .skiing:
            return "figure.skiing.downhill"
        case .snowboarding:
            return "figure.snowboarding"
        case .classicXCSkiing, .freestyleXCSkiing, .backcountrySkiing, .telemarkSkiing:
            return "figure.skiing.crosscountry"
        case .skating, .iceSkating, .inlineSkating, .rollerSkating:
            return "figure.skating"
        case .crossTrainer:
            return "figure.elliptical"
        case .stepWorkout, .stairWorkout:
            return "figure.stair.stepper"
        case .tennis, .beachTennis, .wheelchairTennis:
            return "figure.tennis"
        case .badminton:
            return "figure.badminton"
        case .squash, .padel, .pickleball:
            return "figure.squash"
        case .tableTennis:
            return "figure.table.tennis"
        case .basketball, .wheelchairBasketball:
            return "figure.basketball"
        case .soccer, .futsal:
            return "figure.soccer"
        case .football, .rugby:
            return "figure.american.football"
        case .volleyball, .beachVolleyball:
            return "figure.volleyball"
        case .baseball, .finnishBaseball:
            return "figure.baseball"
        case .golf:
            return "figure.golf"
        case .boxing, .kickboxing, .fitnessBoxing:
            return "figure.boxing"
        case .martialArts, .taekwondo, .judo:
            return "figure.martial.arts"
        case .gymnastics:
            return "figure.gymnastics"
        case .dancing, .fitnessDancing, .ballet, .ballroom, .streetDance, .modernDance, .jazz, .latin:
            return "figure.dance"
        case .climbingIndoor, .climbingOutdoor:
            return "figure.climbing"
        case .core, .pilates:
            return "figure.core.training"
        case .surfing, .windsurfing, .kitesurfing, .wakeboarding, .waterSkiing:
            return "figure.surfing"
        case .sailing:
            return "figure.sailing"
        case .cricket:
            return "figure.cricket"
        default:
            return "figure.run"
        }
    }
}
