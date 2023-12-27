//
//  NetworkManager.swift
//  dualingo-ios
//
//  Created by Kyle Naranjo on 12/27/23.
//

import Foundation
import AVFoundation

class NetworkManager: NSObject, ObservableObject, AVAudioPlayerDelegate{
    @Published var isLoading = false
    @Published var detectedLanguage = ""
    @Published var processedText = ""
    @Published var translatedText = ""
    @Published var audioContentBase64 = ""
    var audioPlayer: AVAudioPlayer?

    let processAndTranslateURL = URL(string: "https://dualingo-app-3rod5lbaca-de.a.run.app/process-and-translate/")!
    let textToSpeechURL = URL(string: "https://dualingo-app-3rod5lbaca-de.a.run.app/text-to-speech/")!
    
    func processAndTranslate(audioURL: URL, languageMode: String) {
        isLoading = true
        // Prepare the request for the translation endpoint
        var request = URLRequest(url: processAndTranslateURL)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        let boundaryPrefix = "--\(boundary)\r\n"
        
        func append(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }
        
        // Append the multipart form data
        append(boundaryPrefix)
        append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(audioURL.lastPathComponent)\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            body.append(audioData)
        } catch {
            print("Error loading audio data: \(error)")
            return
        }
        
        append("\r\n")
        append(boundaryPrefix)
        append("Content-Disposition: form-data; name=\"language_mode\"\r\n\r\n")
        append("\(languageMode)\r\n")
        append("--\(boundary)--\r\n")
        
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        print("Starting processAndTranslate with URL: \(audioURL.absoluteString)")
        print("Language Mode: \(languageMode)")

        // Send the request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false // Ensure to update UI on the main thread
            }
            
            if let error = error {
                print("Error in processAndTranslate request: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Did not receive a valid HTTP response")
                return
            }
            
            print("Response status code: \(httpResponse.statusCode)")

            guard let data = data else {
                print("No data received in processAndTranslate response")
                return
            }

            print("Raw response data in processAndTranslate: \(String(describing: String(data: data, encoding: .utf8)))")

            // Check for server error code (500)
            if httpResponse.statusCode == 500 {
                print("Server error occurred.")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Server response: \(responseString)")
                }
                return
            }

            do {
                let jsonResponse = try JSONDecoder().decode(TranslationResponse.self, from: data)
                DispatchQueue.main.async {
                    // self is used safely here with optional binding since we've weakly captured it
                    self?.detectedLanguage = jsonResponse.detectedLanguage
                    self?.processedText = jsonResponse.processedText
                    self?.translatedText = jsonResponse.translatedText
                    
                    self?.textToSpeech(text: jsonResponse.translatedText, languageCode: jsonResponse.detectedLanguage)
                }
            } catch {
                print("JSON decoding failed: \(error)")
            }
        }.resume()

    }

    
    private func textToSpeech(text: String, languageCode: String) {
        // Prepare the request for the text-to-speech endpoint
        var request = URLRequest(url: textToSpeechURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "text": text,
            "language_code": languageCode
        ]

        do {
            let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = requestBodyData
            print("Request Body to textToSpeech: \(String(data: requestBodyData, encoding: .utf8) ?? "")")
        } catch {
            print("Error encoding request body: \(error)")
            return
        }

        print("Starting textToSpeech with text: \(text)")
        print("Language Code: \(languageCode)")

        // Send the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                print("Error in textToSpeech request: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
            }

            guard let data = data, !data.isEmpty else {
                print("No data received in textToSpeech response or data is empty")
                return
            }

            print("Raw response data in textToSpeech: \(String(describing: String(data: data, encoding: .utf8)))")

            do {
                // Decode the JSON response
                let jsonResponse = try JSONDecoder().decode(TextToSpeechResponse.self, from: data)
                DispatchQueue.main.async {
                    self.audioContentBase64 = jsonResponse.audioContentBase64
                    print("Received audio content with length: \(jsonResponse.audioContentBase64.count) characters")
                    self.playAudio() // Automatically play audio
                    self.isLoading = false // Hide loading indicator
                }
            } catch {
                print("JSON decoding failed: \(error)")
            }
        }.resume()
    }


    func playAudio() {
    
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
            return
        }
        
        guard let audioData = Data(base64Encoded: audioContentBase64) else {
            print("Error decoding audio data")
            return
        }
        print("Audio data length: \(audioData.count) bytes")

        do {
                self.audioPlayer = try AVAudioPlayer(data: audioData) // Change to use the property
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.volume = 1.0 // Optional: set the volume to the maximum
                self.audioPlayer?.play()
            } catch {
                print("Error playing audio: \(error)")
            }
    }
    
    // AVAudioPlayerDelegate methods
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Playback finished. Success: \(flag)")
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Decode error occurred: \(error?.localizedDescription ?? "Unknown error")")
    }


    

    // Structs for decoding JSON responses
    struct TranslationResponse: Codable {
        var detectedLanguage: String
            var processedText: String
            var translatedText: String
            
            enum CodingKeys: String, CodingKey {
                case detectedLanguage = "detected_language"
                case processedText = "processed_text"
                case translatedText = "translated_text"
            }
    }

    struct TextToSpeechResponse: Codable {
        var audioContentBase64: String
        
        enum CodingKeys: String, CodingKey {
            case audioContentBase64 = "audio_content_base64"
        }
    }
    
    func startProcessing(audioURL: URL, languageMode: String) {
            self.isLoading = true // Show loading indicator
            self.reset() // Clear any previous data
            self.processAndTranslate(audioURL: audioURL, languageMode: languageMode)
        }
    
    func reset() {
        isLoading = false
        detectedLanguage = ""
        processedText = ""
        translatedText = ""
        audioContentBase64 = ""
        // Reset the audio player if it's currently playing or exists
        audioPlayer?.stop()
        audioPlayer = nil
    }


}

