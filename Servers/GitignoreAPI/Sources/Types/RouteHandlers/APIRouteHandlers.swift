//
//  APIRouteHandler.swift
//  GitignoreIO
//
//  Created by Joe Blau on 12/17/16.
//
//

import Foundation
import Vapor
import HTTP
import GitignoreEngineKit

//struct Encaps: Content {
//    var encapse = "encapse"
//    var sulation = "sulation"
//}
//
//struct Test: Content {
//    var hello = Encaps()
//}

internal class APIHandlers {
    private let splitSize = 5
    private let order: Order
    private let templates: Templates

    /// Initialze the API Handlers extension
    ///
    /// - Parameter templateController: All of the gitignore template objects
    init(templateController: TemplateController) {
        templates = templateController.templates
        order = templateController.order
    }

    /// Create the API endpoint for serving ignore templates
    ///
    /// - Parameter router: Vapor server side Swift router
    internal func createIgnoreEndpoint(router: Router) {
        router.get("/api", String.parameter) { request -> Response in
            let response = request.response()
            let ignoreString = try request.parameters.next(String.self)
            try response.content.encode(self.createTemplate(ignoreString: ignoreString))
            return response
        }
    }

    /// Create the API endpoint for downloading ignore templates
    ///
    /// - Parameter router: Vapor server side Swift router
    internal func createTemplateDownloadEndpoint(router: Router) {
        router.get("/api/f", String.parameter) { request -> HTTPResponse in
            let ignoreString = try request.parameters.next(String.self)
            return HTTPResponse(status: .ok,
                         version: HTTPVersion(major: 1, minor: 0),
                         headers: HTTPHeaders([(HTTPHeaderName.contentDisposition.description, "attachment; filename=\"gitignore\"")]),
                         body: self.createTemplate(ignoreString: ignoreString))
        }
    }

    /// Create the API endpoint for showing the list of templates
    ///
    /// - Parameter router: Vapor server side Swift router
    internal func createListEndpoint(router: Router) {
        router.get("/api/list") { request -> Response in
            let response = request.response()

            let templateKeys =  self.templates.keys.sorted()
            guard let flags = try? request.query.decode(Flags.self),
                let format = flags.format else {
                let groupedLines =  stride(from: 0, to: templateKeys.count, by: self.splitSize)
                    .map {
                        templateKeys[$0..<min($0 + self.splitSize, templateKeys.count)].joined(separator: ",")
                    }
                    .joined(separator: "\n")
                try response.content.encode(groupedLines)
                return response
            }

            switch format {
            case "lines": try response.content.encode(templateKeys.joined(separator: "\n"))
            case "json": try response.content.encode(json: self.templates)
            default: try response.content.encode("Unknown Format: `lines` or `json` are acceptable formats")
            }
            return response
        }
    }

    /// Create the API endpoint for showing th eorder of templates
    ///
    /// - Parameter router: Vapor server side Swift router
    internal func createOrderEndpoint(router: Router) {
        router.get("/api/order") { request -> Response in
            let response = request.response()
            try response.content.encode(json: self.order)
            return response
        }
    }

    /// Create the API endpoint for help
    ///
    /// - Parameter router: Vapor server side Swift router
    internal func createHelp(router: Router) {
        router.get("/api/") { request in
            """
            gitignore.io help:
              list    - lists the operating systems, programming languages and IDE input types
              :types: - creates .gitignore files for types of operating systems, programming languages or IDEs
            """
        }
    }

    // MARK: - Private

    /// Create final output template sorted based on `data/order` file with headers
    /// and footers applied to templates
    ///
    /// - Parameter ignoreString: Comma separated string of templates to generate
    ///
    /// - Peturns: Final formatted template with headers and footers
    private func createTemplate(ignoreString: String) -> String {
        guard let urlDecoded = ignoreString.removingPercentEncoding else {
            return "\n#!! ERROR: url decoding \(ignoreString) !#\n"
        }
        return urlDecoded
            .lowercased()
            .components(separatedBy: ",")
            .uniqueElements
            .sorted()
            .sorted(by: { (left: String, right: String) -> Bool in
                (self.order[left] ?? 0) < (self.order[right] ?? 0)
            })
            .map { (templateKey) -> String in
                self.templates[templateKey]?.contents ?? "\n#!! ERROR: \(templateKey) is undefined. Use list command to see defined gitignore types !!#\n"
            }
            .reduce("\n# Created by https://www.gitignore.io/api/\(urlDecoded)\n") { (currentTemplate, contents) -> String in
                return currentTemplate.appending(contents)
            }
            .appending("\n\n# End of https://www.gitignore.io/api/\(urlDecoded)\n")
            .removeDuplicateLines()
    }
}
