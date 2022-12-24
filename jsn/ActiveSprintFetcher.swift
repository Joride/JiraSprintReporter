//
//  ActiveSprintFetcher.swift
//  jsn
//
//  Created by Jorrit van Asselt on 22/12/2022.
//

import Foundation

class ActiveSprintFetcher
{
    /// The projectIdentifier this instance was initialized with
    let cookieString: String
    
    let projectKey: String
    
    private let session: URLSession
    
    init(projectKey: String,
         cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral))
    {
        self.projectKey = projectKey
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    
    func fetch() async
    {
        
    }
}
