//
//  TR_IPTVViewModel.swift
//  TV Remote
//

import Foundation
import SwiftUI
import Combine

enum IPTVSectionType: String, CaseIterable, Identifiable {
    case countries = "Countries"
    case categories = "Categories"
    
    var id: String { rawValue }
}

typealias IPTVSection = IPTVSectionType

@MainActor
class TR_IPTVViewModel: ObservableObject {
    @Published var categories: [TR_IPTVCategoryModelElement] = []
    @Published var countries: [TR_IPTVCountryModelElement] = []
    @Published var isLoading = false
    @Published var isDataLoaded = false
    @Published var selectedSection: IPTVSectionType = .countries
    @Published var searchText: String = ""
    
    private let categoryApiUrl = "https://d2is1ss4hhk4uk.cloudfront.net/iptv/iptv_grouped_by_category.json"
    private let countryApiUrl = "https://d2is1ss4hhk4uk.cloudfront.net/iptv/iptv_grouped_by_country.json"
    
    var filteredCountries: [TR_IPTVCountryModelElement] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return countries
        }
        return countries.filter {
            ($0.country ?? "").localizedCaseInsensitiveContains(query) ||
            ($0.countryCodes ?? "").localizedCaseInsensitiveContains(query)
        }
    }
    
    var filteredCategories: [TR_IPTVCategoryModelElement] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return categories
        }
        return categories.filter {
            ($0.category ?? "").localizedCaseInsensitiveContains(query)
        }
    }
    
    func loadAllData() {
        Task {
            isLoading = true
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchCountries() }
                group.addTask { await self.fetchCategories() }
            }
            isLoading = false
            isDataLoaded = true
        }
    }
    
    func fetchCountries() async {
        // 1. Check cached data
        if let cached = getCachedCountries(), !cached.isEmpty {
            self.countries = cached
        }
        
        guard let url = URL(string: countryApiUrl) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return
            }
            let decoded = try JSONDecoder().decode(TR_IPTVCountryModel.self, from: data)
            self.countries = decoded
            cacheCountries(decoded)
        } catch {
            print("Failed to fetch IPTV countries:", error.localizedDescription)
        }
    }
    
    func fetchCategories() async {
        // 1. Check cached data
        if let cached = getCachedCategories(), !cached.isEmpty {
            self.categories = cached
        }
        
        guard let url = URL(string: categoryApiUrl) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return
            }
            let decoded = try JSONDecoder().decode(TR_IPTVCategoryModel.self, from: data)
            self.categories = decoded
            cacheCategories(decoded)
        } catch {
            print("Failed to fetch IPTV categories:", error.localizedDescription)
        }
    }
    
    // MARK: - Caching
    private func cacheCategories(_ items: [TR_IPTVCategoryModelElement]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "Cached_IPTV_Categories")
        }
    }
    
    private func getCachedCategories() -> [TR_IPTVCategoryModelElement]? {
        if let data = UserDefaults.standard.data(forKey: "Cached_IPTV_Categories"),
           let loaded = try? JSONDecoder().decode([TR_IPTVCategoryModelElement].self, from: data) {
            return loaded
        }
        return nil
    }
    
    private func cacheCountries(_ items: [TR_IPTVCountryModelElement]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "Cached_IPTV_Countries")
        }
    }
    
    private func getCachedCountries() -> [TR_IPTVCountryModelElement]? {
        if let data = UserDefaults.standard.data(forKey: "Cached_IPTV_Countries"),
           let loaded = try? JSONDecoder().decode([TR_IPTVCountryModelElement].self, from: data) {
            return loaded
        }
        return nil
    }
}
