//
//  OnboardingView.swift
//  GaugeWatcher
//
//  Welcome screen with location permission request for iOS.
//

import CoreLocation
import SharedFeatures
import SwiftUI

// MARK: - OnboardingView

/// iOS onboarding view with welcome message and location permission request.
struct OnboardingView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<OnboardingReducer>

    var onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                cardContent
                    .frame(width: min(geometry.size.width - 48, 400))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .task {
            store.send(.task)
        }
    }

    // MARK: Private

    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.8),
                Color.accentColor.opacity(0.4),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 0) {
            OnboardingCard(
                store: store,
                onComplete: onComplete)
        }
    }
}

// MARK: - OnboardingCard

private struct OnboardingCard: View {

    // MARK: Internal

    @Bindable var store: StoreOf<OnboardingReducer>

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            headerSection
            locationSection
            actionSection
        }
        .padding(32)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 30, y: 15)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
    }

    // MARK: Private

    private var showPermissionButton: Bool {
        store.authorizationStatus == .notDetermined
    }

    private var locationIcon: String {
        switch store.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            "location.fill"
        case .denied, .restricted:
            "location.slash"
        case .notDetermined:
            "location"
        @unknown default:
            "location"
        }
    }

    private var locationIconColor: Color {
        switch store.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            .green
        case .denied, .restricted:
            .orange
        case .notDetermined:
            .accentColor
        @unknown default:
            .accentColor
        }
    }

    private var locationDescription: String {
        switch store.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            "Location enabled. We'll show you nearby gauges."
        case .denied, .restricted:
            "Location access denied. You can enable it later in Settings."
        case .notDetermined:
            "Allow access to find gauges near you."
        @unknown default:
            "Allow access to find gauges near you."
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 20) {
            // App icon
            Image(systemName: "drop.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .shadow(color: .accentColor.opacity(0.3), radius: 10, y: 5)

            VStack(spacing: 8) {
                Text("Welcome to GaugeWatcher")
                    .font(.title2)
                    .bold()

                Text("Monitor river gauges and water levels across North America and New Zealand")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        VStack(spacing: 16) {
            Divider()

            HStack(spacing: 16) {
                Image(systemName: locationIcon)
                    .font(.title2)
                    .foregroundStyle(locationIconColor)
                    .frame(width: 48, height: 48)
                    .background {
                        Circle()
                            .fill(locationIconColor.opacity(0.15))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Location Access")
                        .font(.headline)

                    Text(locationDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.background.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 16) {
            if showPermissionButton {
                Button {
                    store.send(.requestLocationPermission)
                } label: {
                    HStack {
                        if store.isRequestingPermission {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Enable Location")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isRequestingPermission)

                Button("Skip for Now") {
                    onComplete()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.callout)
            } else {
                Button {
                    onComplete()
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

// MARK: - Preview

#Preview("Not Determined") {
    OnboardingView(
        store: Store(initialState: OnboardingReducer.State()) {
            OnboardingReducer()
        },
        onComplete: { })
}

#Preview("Authorized") {
    OnboardingView(
        store: Store(initialState: OnboardingReducer.State(authorizationStatus: .authorizedWhenInUse)) {
            OnboardingReducer()
        },
        onComplete: { })
}

#Preview("Denied") {
    OnboardingView(
        store: Store(initialState: OnboardingReducer.State(authorizationStatus: .denied)) {
            OnboardingReducer()
        },
        onComplete: { })
}
