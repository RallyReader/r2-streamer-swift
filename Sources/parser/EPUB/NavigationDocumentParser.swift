//
//  NavigationDocumentParser.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 16.05.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import Fuzi

/// The navigation document if documented here at Navigation
/// https://idpf.github.io/a11y-guidelines/
/// http://www.idpf.org/epub/301/spec/epub-contentdocs.html#sec-xhtml-nav-def
final class NavigationDocumentParser {
    
    enum NavType: String {
        case tableOfContents = "toc"
        case pageList = "page-list"
        case landmarks = "landmarks"
        case listOfIllustrations = "loi"
        case listOfTables = "lot"
        case listOfAudiofiles = "loa"
        case listOfVideos = "lov"
    }
    
    private let data: Data
    private let path: String
    
    /// Builds the navigation document parser from Navigation Document data and its path. The path is used to normalize the links' hrefs.
    init(data: Data, at path: String) {
        self.data = data
        self.path = path
    }

    private lazy var document: XMLDocument? = {
        // Warning: Somehow if we use HTMLDocument instead of XMLDocument, then the `epub` prefix doesn't work.
        let document = try? XMLDocument(data: data)
        document?.definePrefix("html", defaultNamespace: "http://www.w3.org/1999/xhtml")
        document?.definePrefix("epub", defaultNamespace: "http://www.idpf.org/2007/ops")
        return document
    }()

    /// Returns the [Link] representation of the navigation list of given type (eg. pageList).
    /// - Parameter type: epub:type of the <nav> element to parse.
    func links(for type: NavType) -> [Link] {
        guard let document = document,
            let nav = document.firstChild(xpath: "//html:nav[@epub:type='\(type.rawValue)']") else
        {
            return []
        }

        return links(in: nav)
    }
    
    /// Parses recursively an <ol> as a list of `Link`.
    private func links(in element: XMLElement) -> [Link] {
        return element.xpath("html:ol[1]/html:li")
            .compactMap { self.link(for: $0) }
    }
    
    /// Parses a <li> element as a `Link`.
    private func link(for li: XMLElement) -> Link? {
        guard let label = li.firstChild(xpath: "html:a|html:span") else {
            return nil
        }
        
        // Cleans up title label.
        // http://www.idpf.org/epub/301/spec/epub-contentdocs.html#confreq-nav-a-cnt
        let title = label.stringValue
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let href: String? = {
            guard let href = label.attr("href") else {
                return nil
            }
            if href.hasPrefix("#") { // fragment inside the Navigation Document itself
                return path + href
            } else {
                return normalize(base: path, href: href)
            }
        }()
        
        let children = links(in: li)
        
        guard
            // A zero-length text label must be ignored
            // http://www.idpf.org/epub/301/spec/epub-contentdocs.html#confreq-nav-a-cnt
            !title.isEmpty,
            // An unlinked item (`span`) without children must be ignored
            // http://www.idpf.org/epub/301/spec/epub-contentdocs.html#confreq-nav-a-nest
            href != nil || !children.isEmpty else
        {
            return nil
        }
        
        return Link(href: href ?? "#", title: title, children: children)
    }

}
