//
//  ContentView.swift
//  DigiNoise
//
//  Simplified main UI
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NoiseViewModel.shared
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 28) {
                    headerView
                    statusCard
                    manualSearchCard
                    Spacer()
                }
                .padding()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                viewModel.sync()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.sync()
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DigiNoise")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.cyan)
                Text("Privacy through noise")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
            }
        }
        .padding(.top, 20)
    }
    
    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(viewModel.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isRunning ? "Active" : "Paused")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $viewModel.isRunning)
                    .tint(.cyan)
                    .labelsHidden()
            }
            
            if viewModel.isRunning {
                HStack {
                    Text("Active: \(viewModel.startHour):00 - \(viewModel.endHour):00")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    if viewModel.dailyLimit > 0 {
                        Text("\(viewModel.dailyRequestCount)/\(viewModel.dailyLimit) today")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }
    
    private var manualSearchCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "safari")
                    .foregroundColor(.cyan)
                Text("Manual Safari Search")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Button {
                Task { await viewModel.manualSafariSearch() }
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Open Random Search")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cyan)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            
            Text("Opens Safari with a random query. No daily limits.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(20)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = NoiseViewModel.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Daily Activity") {
                    Stepper("Limit: \(viewModel.dailyLimit) requests/day", value: $viewModel.dailyLimit, in: 1...20)
                    Text("Set to 0 for unlimited (not recommended)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section("Active Hours") {
                    Stepper("Start: \(viewModel.startHour):00", value: $viewModel.startHour, in: 0...23)
                    Stepper("End: \(viewModel.endHour):00", value: $viewModel.endHour, in: 0...23)
                }
                
                Section {
                    Button("Reset Stats") {
                        viewModel.resetStats()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
