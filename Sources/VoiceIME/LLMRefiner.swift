import Foundation

enum LLMRefinerError: LocalizedError {
    case invalidBaseURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "LLM API Base URL 无效。"
        case .invalidResponse:
            "LLM 返回了无法解析的响应。"
        }
    }
}

final class LLMRefiner {
    func refine(text: String, language: AppLanguage, configuration: LLMConfiguration) async throws -> String {
        let trimmedInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return text
        }

        let endpoint = try makeEndpoint(from: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionsRequest(
                model: configuration.model,
                temperature: 0,
                topP: 0.01,
                maxTokens: max(48, min(256, trimmedInput.count * 2)),
                messages: [
                    .init(role: "system", content: systemPrompt(for: language)),
                    .init(role: "user", content: trimmedInput)
                ]
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LLMRefinerError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        let refined = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let refined, !refined.isEmpty else {
            throw LLMRefinerError.invalidResponse
        }

        return refined
    }

    func test(configuration: LLMConfiguration) async throws -> String {
        try await refine(text: "配森 和 杰森", language: .simplifiedChinese, configuration: configuration)
    }

    private func makeEndpoint(from baseURLString: String) throws -> URL {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let baseURL = URL(string: trimmed) else {
            throw LLMRefinerError.invalidBaseURL
        }

        return baseURL.appending(path: "chat/completions")
    }

    private func systemPrompt(for language: AppLanguage) -> String {
        """
        You are a transcription correction engine for \(language.rawValue).
        Perform only ultra-conservative corrections for obvious ASR mistakes.
        Allowed: fixing clear homophone or terminology mistakes such as 配森 -> Python, 杰森 -> JSON.
        Forbidden: rewriting, polishing, summarizing, translating, reordering, expanding, shortening, changing tone, or adding stylistic punctuation.
        Preserve wording, sequence, spacing, and mixed-language tokens unless a token is clearly wrong.
        If there is no obvious error, return the original text unchanged.
        Output only the corrected text.
        """
    }
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let messages: [ChatMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionsResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
