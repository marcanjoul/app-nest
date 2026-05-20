import Foundation
import SwiftData

// MARK: - Application Type

/// The type of employment for a job application.
///
/// Provides common employment categories with user-friendly display names.
enum ApplicationType: String, CaseIterable, Codable {
    case fullTime = "Full Time"
    case partTime = "Part Time"
    case contract = "Contract"
    case internship = "Internship"
    case Co_op = "Co-op"
    case temporary = "Temporary"
}

// MARK: - Application Season

/// The season when a position is expected to start.
///
/// Particularly useful for tracking internships and co-op positions,
/// which are often organized by academic seasons.
enum ApplicationSeason: String, CaseIterable, Codable {
    case winter = "Winter"
    case spring = "Spring"
    case summer = "Summer"
    case fall = "Fall"
}

// MARK: - Compensation

/// Whether the compensation is paid hourly or as a salary.
enum CompensationKind: String, CaseIterable, Codable {
    case hourly = "Hourly"
    case salary = "Salary"
}

/// Period used for salary compensation.
enum SalaryPeriod: String, CaseIterable, Codable {
    case yearly = "Year"
    case monthly = "Month"
}

/// Supported currencies for compensation entry.
enum Currency: String, CaseIterable, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case aud = "AUD"
    case jpy = "JPY"
    case cny = "CNY"
    case inr = "INR"
    case chf = "CHF"
    case mxn = "MXN"

    var symbol: String {
        switch self {
        case .usd, .cad, .aud, .mxn: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy, .cny: return "¥"
        case .inr: return "₹"
        case .chf: return "₣"
        }
    }
}

// MARK: - Application Status

/// The current status of a job application in the hiring pipeline.
///
/// Tracks progression from initial planning through final outcome.
enum ApplicationStatus: String, CaseIterable, Codable {
    /// Planned to apply but not yet submitted
    case toApply = "To Apply"
    
    /// Application has been submitted
    case applied = "Applied"
    
    /// Currently in the interview process
    case interview = "Interview"
    
    /// Received a job offer
    case offer = "Offer"
    
    /// Application was rejected or position filled
    case rejected = "Rejected"
}

// MARK: - Model

/// SwiftData model representing a persistent job application record.
///
/// This model is designed for storage in the app's database using SwiftData.
/// It mirrors the structure of the `JobApplication` struct above but is intended for
/// persistent use, handling company details, application status, and attachments.
///
/// Properties correspond to relevant job and company information, as well as optional
/// user notes and attachments.
@Model
class JobApplication {
    /// Name of the company applied to (e.g., "Apple").
    var companyName: String
    
    /// Optional custom image data uploaded by user for company logo.
    var companyLogoImageData: Data?
    
    /// Job position/title applied for (e.g., "Software Engineer").
    var position: String
    
    /// Type of employment (full-time, internship, etc.).
    var jobType: ApplicationType?
    
    /// Current status of the application in the hiring process.
    var status: ApplicationStatus?
    
    /// Season when the position is expected to start.
    var season: ApplicationSeason?

    /// The job search cycle this application belongs to (optional).
    var cycle: JobCycle?
    
    /// Date the application was submitted.
    var dateApplied: Date
    
    /// URL of the original job posting.
    var jobURL: String?

    /// Optional notes or details added by the user.
    var jobNotes: String?

    /// Notes on company background, mission, and culture for interview prep.
    var companyResearch: String?

    /// STAR stories, questions to ask, and talking points for the interview.
    var interviewNotes: String?

    /// Optional filename of the attached resume.
    var resumeFileName: String?
    
    /// Security-scoped bookmark data for attached resume file.
    var resumeBookmark: Data?

    /// Identifier for the resume profile item attached to this job.
    var resumeID: UUID?

    /// Whether compensation is paid hourly or as a salary.
    var compensationKind: CompensationKind?

    /// Numeric compensation amount (interpreted with `compensationKind` and `salaryPeriod`).
    var compensationAmount: Double?

    /// Currency for the compensation amount (defaults to USD).
    var compensationCurrency: Currency?

    /// Period (year/month) for salary compensation. Ignored for hourly.
    var salaryPeriod: SalaryPeriod?

    /// Whether the user has requested a local notification reminder for this application.
    /// Only meaningful while `status == .toApply`.
    var reminderEnabled: Bool = false

    /// The time-of-day at which the reminder fires. Defaults to 9 AM if nil.
    var reminderTime: Date?

    /// Identifier for the scheduled `UNNotificationRequest`, if any. Used to cancel/replace.
    var reminderNotificationID: String?

    /// Creates a new persistent job application.
    ///
    /// All parameters are persisted to storage. Defaults are provided for optional values.
    /// - Parameters:
    ///   - companyName: Name of the company.
    ///   - companyLogoImageData: Custom logo image data, if provided.
    ///   - position: Job position/title applied for.
    ///   - jobType: Employment type (optional).
    ///   - status: Application status (default `.applied`).
    ///   - season: Season when the position begins (optional).
    ///   - dateApplied: Date the application was submitted (default: now).
    ///   - jobNotes: Optional notes or details.
    ///   - resumeFileName: Filename of the attached resume (optional).
    ///   - resumeBookmark: Security-scoped bookmark data for resume (optional).
    init(
        companyName: String,
        companyLogoImageData: Data? = nil,
        position: String,
        jobType: ApplicationType? = nil,
        status: ApplicationStatus? = .applied,
        season: ApplicationSeason? = nil,
        cycle: JobCycle? = nil,
        dateApplied: Date = Date(),
        jobURL: String? = nil,
        jobNotes: String? = nil,
        resumeFileName: String? = nil,
        resumeBookmark: Data? = nil,
        resumeID: UUID? = nil,
        compensationKind: CompensationKind? = nil,
        compensationAmount: Double? = nil,
        compensationCurrency: Currency? = .usd,
        salaryPeriod: SalaryPeriod? = nil,
        reminderEnabled: Bool = false,
        reminderTime: Date? = nil,
        reminderNotificationID: String? = nil
    ) {
        self.companyName = companyName
        self.companyLogoImageData = companyLogoImageData
        self.position = position
        self.jobType = jobType
        self.status = status
        self.season = season
        self.cycle = cycle
        self.dateApplied = dateApplied
        self.jobURL = jobURL
        self.jobNotes = jobNotes
        self.resumeFileName = resumeFileName
        self.resumeBookmark = resumeBookmark
        self.resumeID = resumeID
        self.compensationKind = compensationKind
        self.compensationAmount = compensationAmount
        self.compensationCurrency = compensationCurrency
        self.salaryPeriod = salaryPeriod
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.reminderNotificationID = reminderNotificationID
    }
}

// MARK: - Resume Document

/// SwiftData model representing a reusable resume managed from the profile.
@Model
class ResumeDocument {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var bookmark: Data
    var isDefault: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        bookmark: Data,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.bookmark = bookmark
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}
