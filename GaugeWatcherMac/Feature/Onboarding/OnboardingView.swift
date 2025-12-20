//
//  OnboardingView.swift
//  GaugeWatcherMac
//
//  Created by Andrew Althage on 12/19/25.
//

import CoreLocation
import SharedFeatures
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    // MARK: Internal

    @Bindable var store: StoreOf<OnboardingReducer>
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            backgroundImage
            cardContent
        }
        .ignoresSafeArea()
        .task {
            store.send(.task)
        }
    }

    // MARK: Private

    @ViewBuilder
    private var backgroundImage: some View {
        Image("Hero")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(0.7),
                        .black.opacity(0.4),
                        .black.opacity(0.7),
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
            }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 0) {
            OnboardingCard(
                store: store,
                onComplete: onComplete)
        }
        .frame(maxWidth: 480)
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
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
    }

    // MARK: Private

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .opacity(0.5)

            VStack(spacing: 8) {
                Text("Welcome to GaugeWatcher")
                    .font(.title)
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
                    .frame(width: 44, height: 44)
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
                }

                Spacer()
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
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
                                .controlSize(.small)
                        } else {
                            Text("Enable Location")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
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
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var showPermissionButton: Bool {
        store.authorizationStatus == .notDetermined
    }

    private var locationIcon: String {
        switch store.authorizationStatus {
        case .authorized, .authorizedAlways:
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
        case .authorized, .authorizedAlways:
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
        case .authorized, .authorizedAlways:
            "Location enabled. We'll show you nearby gauges."
        case .denied, .restricted:
            "Location access denied. You can enable it later in System Settings."
        case .notDetermined:
            "Allow access to find gauges near you."
        @unknown default:
            "Allow access to find gauges near you."
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
        store: Store(initialState: OnboardingReducer.State(authorizationStatus: .authorized)) {
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
