//
//  File.swift
//  
//
//  Created by 姜锋 on 5/11/24.
//

import Foundation
import SwiftyJSON

// 函数将异步执行，并且使用 Swift 5.5 引入的 async/await
func fetchJSONData(from urlString: String) async throws -> JSON {
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL)
    }

    let (data, _) = try await URLSession.shared.data(from: url)

    let json = try JSON(data: data)
    return json
}
