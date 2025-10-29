//
//  ErrorLogger.swift
//  TrebleSurf
//
//  Centralized logging system for errors and events
//

import Foundation
import os.log

// MARK: - Log Level

enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Log Category

enum LogCategory: String {
    case network = "Network"
    case authentication = "Auth"
    case api = "API"
    case cache = "Cache"
    case media = "Media"
    case validation = "Validation"
    case dataProcessing = "Data"
    case ui = "UI"
    case general = "General"
}

// MARK: - Logger Protocol

protocol ErrorLoggerProtocol {
    func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int)
    func logError(_ error: TrebleSurfError, context: String?, file: String, function: String, line: Int)
    func logEvent(_ event: String, metadata: [String: Any]?, category: LogCategory, file: String, function: String, line: Int)
}

// MARK: - Protocol Extension with Default Parameters

extension ErrorLoggerProtocol {
    func log(_ message: String, level: LogLevel, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: level, category: category, file: file, function: function, line: line)
    }
    
    func logError(_ error: TrebleSurfError, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        logError(error, context: context, file: file, function: function, line: line)
    }
    
    func logEvent(_ event: String, metadata: [String: Any]? = nil, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        logEvent(event, metadata: metadata, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Error Logger Implementation

final class ErrorLogger: ErrorLoggerProtocol {
    
    // MARK: - Configuration
    
    private let subsystem = "com.treblesurf.app"
    private let minimumLogLevel: LogLevel
    private let enableConsoleOutput: Bool
    private let enableOSLog: Bool
    
    // MARK: - Initialization
    
    init(minimumLogLevel: LogLevel = .info, 
         enableConsoleOutput: Bool = true,
         enableOSLog: Bool = true) {
        self.minimumLogLevel = minimumLogLevel
        self.enableConsoleOutput = enableConsoleOutput
        self.enableOSLog = enableOSLog
    }
    
    // MARK: - Public Methods
    
    func log(_ message: String, 
             level: LogLevel, 
             category: LogCategory,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        guard level.rawValue >= minimumLogLevel.rawValue else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let logMessage = formatMessage(message, level: level, category: category, file: fileName, function: function, line: line)
        
        if enableConsoleOutput {
            print(logMessage)
        }
        
        if enableOSLog {
            let osLog = OSLog(subsystem: subsystem, category: category.rawValue)
            os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
        }
    }
    
    func logError(_ error: TrebleSurfError,
                  context: String? = nil,
                  file: String = #file,
                  function: String = #function,
                  line: Int = #line) {
        
        let fileName = (file as NSString).lastPathComponent
        
        var message = """
        Error [\(error.errorCode)]: \(error.userMessage)
        Category: \(error.category.rawValue)
        Technical: \(error.technicalDetails)
        """
        
        if let context = context {
            message += "\nContext: \(context)"
        }
        
        message += "\nRetryable: \(error.isRetryable)"
        
        if !error.recoverySuggestions.isEmpty {
            message += "\nRecovery: \(error.recoverySuggestions.joined(separator: ", "))"
        }
        
        if let underlyingError = error.underlyingError {
            message += "\nUnderlying: \(underlyingError)"
        }
        
        let logMessage = formatMessage(message, level: .error, category: categoryFrom(error), file: fileName, function: function, line: line)
        
        if enableConsoleOutput {
            print(logMessage)
        }
        
        if enableOSLog {
            let osLog = OSLog(subsystem: subsystem, category: categoryFrom(error).rawValue)
            os_log("%{public}@", log: osLog, type: .error, logMessage)
        }
    }
    
    func logEvent(_ event: String,
                  metadata: [String: Any]? = nil,
                  category: LogCategory,
                  file: String = #file,
                  function: String = #function,
                  line: Int = #line) {
        
        var message = "Event: \(event)"
        
        if let metadata = metadata {
            let metadataString = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " | \(metadataString)"
        }
        
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Private Helpers
    
    private func formatMessage(_ message: String,
                              level: LogLevel,
                              category: LogCategory,
                              file: String,
                              function: String,
                              line: Int) -> String {
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        return "\(level.emoji) [\(timestamp)] [\(category.rawValue)] \(file):\(line) \(function) - \(message)"
    }
    
    private func categoryFrom(_ error: TrebleSurfError) -> LogCategory {
        switch error.category {
        case .network: return .network
        case .authentication: return .authentication
        case .api: return .api
        case .validation: return .validation
        case .media: return .media
        case .cache: return .cache
        case .dataProcessing: return .dataProcessing
        default: return .general
        }
    }
}

// MARK: - Convenience Methods

extension ErrorLogger {
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Mock Logger for Testing

final class MockErrorLogger: ErrorLoggerProtocol {
    
    struct LogEntry {
        let message: String
        let level: LogLevel
        let category: LogCategory
        let timestamp: Date
    }
    
    struct ErrorEntry {
        let error: TrebleSurfError
        let context: String?
        let timestamp: Date
    }
    
    private(set) var logEntries: [LogEntry] = []
    private(set) var errorEntries: [ErrorEntry] = []
    private(set) var eventEntries: [LogEntry] = []
    
    func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        logEntries.append(LogEntry(message: message, level: level, category: category, timestamp: Date()))
    }
    
    func logError(_ error: TrebleSurfError, context: String?, file: String, function: String, line: Int) {
        errorEntries.append(ErrorEntry(error: error, context: context, timestamp: Date()))
    }
    
    func logEvent(_ event: String, metadata: [String: Any]?, category: LogCategory, file: String, function: String, line: Int) {
        eventEntries.append(LogEntry(message: event, level: .info, category: category, timestamp: Date()))
    }
    
    func clear() {
        logEntries.removeAll()
        errorEntries.removeAll()
        eventEntries.removeAll()
    }
}

