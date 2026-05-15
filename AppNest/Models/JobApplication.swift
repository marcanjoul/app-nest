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
    
    /// Asset catalog name for the company's logo image.
    var companyLogoName: String
    
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
    
    /// Date the application was submitted.
    var dateApplied: Date
    
    /// Optional notes or details added by the user.
    var jobNotes: String?
    
    /// Optional filename of the attached resume.
    var resumeFileName: String?
    
    /// Security-scoped bookmark data for attached resume file.
    var resumeBookmark: Data?
    
    /// Creates a new persistent job application.
    ///
    /// All parameters are persisted to storage. Defaults are provided for optional values.
    /// - Parameters:
    ///   - companyName: Name of the company.
    ///   - companyLogoName: Asset name for pre-defined logos (default "").
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
        companyLogoName: String = "",
        companyLogoImageData: Data? = nil,
        position: String,
        jobType: ApplicationType? = nil,
        status: ApplicationStatus? = .applied,
        season: ApplicationSeason? = nil,
        dateApplied: Date = Date(),
        jobNotes: String? = nil,
        resumeFileName: String? = nil,
        resumeBookmark: Data? = nil
    ) {
        self.companyName = companyName
        self.companyLogoName = companyLogoName
        self.companyLogoImageData = companyLogoImageData
        self.position = position
        self.jobType = jobType
        self.status = status
        self.season = season
        self.dateApplied = dateApplied
        self.jobNotes = jobNotes
        self.resumeFileName = resumeFileName
        self.resumeBookmark = resumeBookmark
    }
}
