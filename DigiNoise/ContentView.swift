//
//  ContentView.swift
//  DigiNoise
//
//  Main UI Views
//

import SwiftUI

// MARK: - Main View
struct ContentView: View {
    @StateObject private var viewModel = NoiseViewModel.shared
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showInfo = false
    @State private var showOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        mainControlCard
                        backgroundNoticeCard
                        safariSearchCard
                        scheduleCard
                    }
                    .padding(.horizontal)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showInfo) { InfoView() }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .onAppear {
                if !viewModel.hasCompletedOnboarding {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showOnboarding = true
                    }
                }
                viewModel.checkAutoResume()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.checkAutoResume()
                }
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.15, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DigiNoise")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                Text("Promoting privacy")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.7))
            }
            Spacer()
            HStack(spacing: 16) {
                HeaderButton(icon: "chart.bar.fill") { showStats = true }
                HeaderButton(icon: "info.circle.fill") { showInfo = true }
                HeaderButton(icon: "gearshape.fill") { showSettings = true }
            }
        }
        .padding(.top, 20)
    }
    
    private var mainControlCard: some View {
        GlassCard {
            VStack(spacing: 20) {
                statusToggleRow
                apiTrafficDescription
                Divider().background(Color.white.opacity(0.2))
                statsRows
                if viewModel.isRunning && viewModel.lastSearchDescription != "None" {
                    Divider().background(Color.white.opacity(0.2))
                    lastRequestSection
                }
            }
            .padding(20)
        }
    }
    
    private var statusToggleRow: some View {
        HStack {
            HStack {
                Circle()
                    .fill(viewModel.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isRunning ? "Active" : "Paused")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { viewModel.isRunning },
                set: { newValue in
                    if newValue {
                        viewModel.start()
                    } else {
                        viewModel.stop()
                    }
                }
            ))
            .tint(.cyan)
            .labelsHidden()
        }
    }
    
    private var apiTrafficDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.cyan)
                Text("Background API Traffic")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            Text("Automated requests to Wikipedia (\(viewModel.enabledAPILanguages.count) languages), weather, news, and more")
                .font(.caption)
                .foregroundColor(Color(white: 0.6))
        }
    }
    
    private var statsRows: some View {
        VStack(spacing: 12) {
            InfoRow(label: "API Requests Today", value: "\(viewModel.todaySearches) / \(viewModel.dailyAPILimit)")
            InfoRow(label: "Total Requests", value: "\(viewModel.stats.totalSearches)")
            InfoRow(label: "Next Request In", value: viewModel.timeRemaining)
            InfoRow(label: "Status", value: viewModel.currentStatus)
        }
    }
    
    private var lastRequestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.cyan)
                Text("Last Request")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.7))
            }
            Text(viewModel.lastSearchDescription)
                .font(.caption)
                .foregroundColor(Color(white: 0.6))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var backgroundNoticeCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("iOS Background Limitations")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Text("iOS controls background execution. Tasks run when iOS allows based on battery, network, and usage. For guaranteed execution, keep the app in foreground.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }
    
    private var safariSearchCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                safariSearchHeader
                safariSearchButton
                Text("Opens Safari with a random search query. No daily limits.")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.5))
            }
            .padding(20)
        }
    }
    
    private var safariSearchHeader: some View {
        HStack {
            Image(systemName: "safari")
                .font(.title2)
                .foregroundColor(.cyan)
            VStack(alignment: .leading, spacing: 4) {
                Text("Manual Safari Searches")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Generate visible search noise on-demand")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.6))
            }
            Spacer()
        }
    }
    
    private var safariSearchButton: some View {
        Button(action: {
            Task { await viewModel.performManualVisibleSearch() }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                Text("Open Random Search in Safari")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
            .foregroundColor(.white)
            .cornerRadius(14)
            .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private var scheduleCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                scheduleHeader
                scheduleLimitsRow
            }
            .padding(20)
        }
    }
    
    private var scheduleHeader: some View {
        HStack {
            Image(systemName: "clock.badge.checkmark")
                .font(.title2)
                .foregroundColor(.cyan)
            VStack(alignment: .leading, spacing: 4) {
                Text("Schedule")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(viewModel.scheduleDisplayText)
                    .font(.title3)
                    .foregroundColor(.cyan)
            }
            Spacer()
        }
    }
    
    private var scheduleLimitsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Limit")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.6))
                Text("\(viewModel.dailyAPILimit) requests/day")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Languages")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.6))
                Text("\(viewModel.enabledAPILanguages.count) enabled")
                    .font(.subheadline)
                    .foregroundColor(.cyan)
            }
        }
    }
}

// MARK: - Header Button
struct HeaderButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.cyan)
                .padding(8)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Circle())
        }
    }
}

// MARK: - Glass Card
struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20) 
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(white: 0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = NoiseViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSchedule = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                settingsForm
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $showSchedule) { WeeklyScheduleView() }
        }
    }
    
    private var settingsForm: some View {
        Form {
            apiSettingsSection
            scheduleSection
            apiCategoriesSection
            languagesSection
            safariCategoriesSection
            privacySection
        }
        .scrollContentBackground(.hidden)
    }
    
    private var apiSettingsSection: some View {
        Section("Background API Settings") {
            Picker("Daily API Limit", selection: $viewModel.dailyAPILimit) {
                Text("Inactive").tag(0)
                Text("1/day").tag(1)
                Text("2/day").tag(2)
                Text("3/day").tag(3)
                Text("5/day").tag(5)
                Text("10/day").tag(10)
            }
            .tint(.cyan)
        }
    }
    
    private var scheduleSection: some View {
        Section("Schedule") {
            Toggle("Custom Weekly Schedule", isOn: $viewModel.useCustomSchedule)
                .tint(.cyan)
            
            if !viewModel.useCustomSchedule {
                Stepper("Start: \(viewModel.startHour):00", value: $viewModel.startHour, in: 0...23)
                Stepper("End: \(viewModel.endHour):00", value: $viewModel.endHour, in: 0...23)
            } else {
                Button("Configure Weekly Schedule") { showSchedule = true }
            }
        }
    }
    
    private var apiCategoriesSection: some View {
        Section("API Categories") {
            ForEach(APICategory.allCases) { category in
                Toggle(category.rawValue, isOn: Binding(
                    get: { viewModel.enabledAPICategories.contains(category) },
                    set: { enabled in
                        if enabled {
                            viewModel.enabledAPICategories.insert(category)
                        } else {
                            viewModel.enabledAPICategories.remove(category)
                        }
                    }
                ))
                .tint(.cyan)
            }
        }
    }
    
    private var languagesSection: some View {
        Section("Wikipedia Languages") {
            ForEach(APILanguage.allCases) { language in
                Toggle(language.rawValue, isOn: Binding(
                    get: { viewModel.enabledAPILanguages.contains(language) },
                    set: { enabled in
                        if enabled {
                            viewModel.enabledAPILanguages.insert(language)
                        } else if viewModel.enabledAPILanguages.count > 1 {
                            viewModel.enabledAPILanguages.remove(language)
                        }
                    }
                ))
                .tint(.cyan)
            }
        }
    }
    
    private var safariCategoriesSection: some View {
        Section("Safari Search Categories") {
            ForEach(SearchGenerator.Category.allCases) { category in
                Toggle(category.rawValue, isOn: Binding(
                    get: { viewModel.enabledCategories.contains(category) },
                    set: { enabled in
                        if enabled {
                            viewModel.enabledCategories.insert(category)
                        } else {
                            viewModel.enabledCategories.remove(category)
                        }
                    }
                ))
                .tint(.cyan)
            }
        }
    }
    
    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Stealth Mode", isOn: $viewModel.stealthMode)
                .tint(.cyan)
            Text("Disables all notifications and haptic feedback")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Stats View
struct StatsView: View {
    @StateObject private var viewModel = NoiseViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var expandedRecordID: UUID?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        statsCards
                        reliabilityCard
                        historyCard
                        resetButton
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.cyan)
                }
            }
        }
    }
    
    private var statsCards: some View {
        HStack(spacing: 16) {
            StatCard(title: "Today", value: "\(viewModel.todaySearches)", color: .cyan)
            StatCard(title: "Total", value: "\(viewModel.stats.totalSearches)", color: .green)
        }
        .padding(.horizontal)
    }

    private var reliabilityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reliability").font(.headline).foregroundColor(.white)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Success Rate").font(.caption).foregroundColor(.gray)
                        Text("\(viewModel.stats.successRate, specifier: "%.1f")%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.stats.successRate >= 90 ? .green : .orange)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("\(viewModel.stats.successfulRequests)")
                                .foregroundColor(.white)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("\(viewModel.stats.failedRequests)")
                                .foregroundColor(.white)
                        }
                    }
                    .font(.subheadline)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var historyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity").font(.headline).foregroundColor(.white)
                
                if viewModel.stats.searchHistory.isEmpty {
                    Text("No activity yet").foregroundColor(.gray).padding(.vertical, 20)
                } else {
                    ForEach(viewModel.stats.searchHistory.prefix(15)) { record in
                        HistoryRow(record: record, expandedRecordID: $expandedRecordID)
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var resetButton: some View {
        Button("Reset Statistics") { viewModel.resetStats() }
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.2))
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let record: SearchStats.SearchRecord
    @Binding var expandedRecordID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                withAnimation {
                    expandedRecordID = expandedRecordID == record.id ? nil : record.id
                }
            }) {
                HStack {
                    Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(record.success ? .green : .red)
                        .font(.caption)
                    Text(record.query)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    if record.mode == "Background API" {
                        Image(systemName: "info.circle").foregroundColor(.cyan).font(.caption)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                Text(record.timestamp, style: .time)
                Text("•")
                Text(record.mode)
                if let lang = record.apiLanguage {
                    Text("•")
                    Text(lang)
                }
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            if expandedRecordID == record.id {
                expandedDetails
            }
            
            Divider().background(Color.white.opacity(0.1))
        }
    }
    
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let category = record.apiCategory {
                Text("Category: \(category)").font(.caption).foregroundColor(.cyan)
            }
            if let url = record.apiURL {
                Text(url).font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(value).font(.system(size: 36, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Info View
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("About DigiNoise").font(.title2.bold()).foregroundColor(.white)
                        
                        InfoSection(icon: "shield.fill", title: "How It Works",
                            description: "Creates privacy through obfuscation with automated API calls and manual Safari searches.")
                        
                        InfoSection(icon: "exclamationmark.triangle.fill", title: "iOS Limitations",
                            description: "iOS controls background execution. Tasks run opportunistically based on battery, network, and usage. Keep app in foreground for guaranteed execution.")
                        
                        InfoSection(icon: "globe", title: "Multilingual",
                            description: "Wikipedia requests in 12 languages. Configure in Settings.")
                        
                        InfoSection(icon: "lock.fill", title: "Privacy First",
                            description: "All data stays on device. No analytics, tracking, or cloud storage.")
                    }
                    .padding()
                }
            }
            .navigationTitle("Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.cyan)
                }
            }
        }
    }
}

// MARK: - Info Section
struct InfoSection: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundColor(.cyan).frame(width: 30)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline).foregroundColor(.white)
                Text(description).font(.subheadline).foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Weekly Schedule View
struct WeeklyScheduleView: View {
    @StateObject private var viewModel = NoiseViewModel.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    ForEach($viewModel.weeklySchedule) { $schedule in
                        Section(schedule.dayName) {
                            Toggle("Enable", isOn: $schedule.isEnabled).tint(.cyan)
                            if schedule.isEnabled {
                                Stepper("Start: \(schedule.startHour):00", value: $schedule.startHour, in: 0...23)
                                Stepper("End: \(schedule.endHour):00", value: $schedule.endHour, in: 0...23)
                            }
                        }
                    }
                    
                    Section {
                        Button("Reset to Default") {
                            viewModel.weeklySchedule = (1...7).map {
                                DaySchedule(dayOfWeek: $0, isEnabled: true, startHour: 7, endHour: 23)
                            }
                        }
                        .foregroundColor(.orange)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Weekly Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.cyan)
                }
            }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @StateObject private var viewModel = NoiseViewModel.shared
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.1, green: 0.15, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                if currentPage < 2 {
                    skipButton
                }
                
                TabView(selection: $currentPage) {
                    OnboardingPage1().tag(0)
                    OnboardingPage2().tag(1)
                    OnboardingPage3(isPresented: $isPresented).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
    }
    
    private var skipButton: some View {
        HStack {
            Spacer()
            Button("Skip") {
                viewModel.hasCompletedOnboarding = true
                isPresented = false
            }
            .foregroundColor(.cyan)
            .padding()
        }
    }
}

// MARK: - Onboarding Page 1
struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "shield.checkered")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text("DigiNoise")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.white)
            
            Text("Add realistic network diversity to your digital footprint")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Text("Swipe to continue")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Onboarding Page 2
struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text("Background API Calls")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "globe", title: "12 Languages", desc: "Wikipedia requests worldwide")
                FeatureRow(icon: "calendar", title: "iOS Controlled", desc: "Runs when system allows")
                FeatureRow(icon: "battery.100", title: "Minimal Impact", desc: "<0.001% battery per day")
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}

// MARK: - Onboarding Page 3
struct OnboardingPage3: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = NoiseViewModel.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.cyan, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text("Privacy First")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                PrivacyRow(icon: "eye.slash.fill", text: "No data collection")
                PrivacyRow(icon: "iphone", text: "Everything on device")
                PrivacyRow(icon: "chart.bar.xaxis", text: "No analytics")
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            getStartedButton
        }
    }
    
    private var getStartedButton: some View {
        Button(action: {
            viewModel.hasCompletedOnboarding = true
            isPresented = false
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Get Started").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundColor(.cyan).frame(width: 30)
            VStack(alignment: .leading) {
                Text(title).font(.headline).foregroundColor(.white)
                Text(desc).font(.caption).foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Privacy Row
struct PrivacyRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title3).foregroundColor(.green).frame(width: 30)
            Text(text).foregroundColor(.white)
        }
    }
}

#Preview {
    ContentView()
}
