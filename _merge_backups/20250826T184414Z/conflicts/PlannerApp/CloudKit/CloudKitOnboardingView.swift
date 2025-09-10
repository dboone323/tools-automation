// PlannerApp/CloudKit/CloudKitOnboardingView.swift
import CloudKit
import Foundation
import SwiftUI

struct CloudKitOnboardingView: View {
    @StateObject private var cloudKit = EnhancedCloudKitManager.shared // Changed to EnhancedCloudKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingPermission = false
    @State private var showingMergeOptions = false

    @AppStorage("hasCompletedCloudKitOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header image
                Image(systemName: "icloud")
                    .font(.system(size: 80))
                    .foregroundStyle(.linearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .top, endPoint: .bottom))
                    .padding(.top, 30)

                Text("Sync With iCloud")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Benefits explanation
                VStack(alignment: .leading, spacing: 16) {
                    benefitRow(icon: "iphone.and.arrow.forward", title: "Sync Across Devices",
                               description: "Access your tasks, goals, and events on all your Apple devices.")

                    benefitRow(icon: "lock.shield", title: "Private & Secure",
                               description: "Your data is encrypted and protected by your Apple ID.")

                    benefitRow(icon: "arrow.clockwise.icloud", title: "Automatic Backup",
                               description: "Never lose your important information with automatic backups.")

                    benefitRow(icon: "person.crop.circle", title: "Just for You",
                               description: "Your data is only visible to you, never shared with others.")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.1))
                )
                .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        requestiCloudAccess()
                    } label: {
                        Text("Enable iCloud Sync")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isRequestingPermission)
                    .overlay {
                        if isRequestingPermission {
                            ProgressView()
                                .tint(.white)
                        }
                    }

                    Button {
                        skipOnboarding()
                    } label: {
                        Text("Maybe Later")
                            .padding()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert("This is a New Device", isPresented: $showingMergeOptions) {
                Button("Merge from iCloud") {
                    mergeFromiCloud()
                }

                Button("Start Fresh") {
                    startFresh()
                }
            } message: {
                Text("Do you want to merge existing iCloud data with this device, or start fresh?")
            }
        }
    }

    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func requestiCloudAccess() {
        isRequestingPermission = true

        _Concurrency.Task {
            await cloudKit.requestiCloudAccess()
            await cloudKit.checkAccountStatus()

            DispatchQueue.main.async {
                isRequestingPermission = false

                if cloudKit.isSignedInToiCloud {
                    showingMergeOptions = true
                }
            }
        }
    }

    private func mergeFromiCloud() {
        _Concurrency.Task {
            await cloudKit.handleNewDeviceLogin()
            completeOnboarding()
        }
    }

    private func startFresh() {
        UserDefaults.standard.set(true, forKey: "HasCompletedInitialSync")
        completeOnboarding()
    }

    private func skipOnboarding() {
        completeOnboarding()
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    CloudKitOnboardingView()
}
