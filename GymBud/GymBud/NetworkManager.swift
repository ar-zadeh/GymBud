import Foundation
import Combine
import SwiftUI

// Based on the Python FastAPI server expectations
struct ChatRequest: Codable {
    let message: String
    let history: [[String: String]]
    let goals: String
}

struct ChatResponse: Codable {
    let reply: String
}

class NetworkManager: ObservableObject {
    @Published var chatHistory: [[String: String]] = []
    @Published var isLoading = false
    
    // Change this to your server's IP address if running on a real iOS device (e.g. 192.168.1.x)
    // 127.0.0.1 and localhost works perfectly for iOS Simulator directly targeting mac.
    let serverURL = "http://127.0.0.1:8000/trainer/chat"
    
    func sendMessage(_ text: String, goals: String) {
        let currentMessage = ["role": "user", "content": text]
        DispatchQueue.main.async {
            self.chatHistory.append(currentMessage)
            self.isLoading = true
        }
        
        let requestBody = ChatRequest(message: text, history: chatHistory, goals: goals)
        
        guard let url = URL(string: serverURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
        } catch {
            print("Encoding error: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            guard let data = data, error == nil else {
                print("Network request failed: \(String(describing: error))")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let responseData = try decoder.decode(ChatResponse.self, from: data)
                DispatchQueue.main.async {
                    self.chatHistory.append(["role": "assistant", "content": responseData.reply])
                }
            } catch {
                print("Decoding failed: \(error)")
            }
        }.resume()
    }
}
