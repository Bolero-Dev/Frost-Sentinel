//
//  GardenView.swift
//  FrostSentinel
//
//  The whole app on one screen: tonight's low, and a verdict per plant.
//  Deliberately quiet — no radar, no charts, no alerts. Just the answer.
//

import SwiftUI

struct GardenView: View {
    @ObservedObject var viewModel: GardenViewModel
    let store: GardenStore

    // A location is two numbers, not a permission dialog. Default: Salt Lake City.
    @AppStorage("latitude") private var latitude: Double = 40.76
    @AppStorage("longitude") private var longitude: Double = -111.89

    @State private var plants: [PlantEntity] = []
    @State private var isShowingAddSheet = false
    @State private var isShowingLocationSheet = false

    var body: some View {
        NavigationStack {
            List {
                tonightSection
                verdictSection
            }
            .navigationTitle("Frost Sentinel")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Location") { isShowingLocationSheet = true }
                        .accessibilityIdentifier("garden.location")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Label("Add Plant", systemImage: "plus")
                    }
                    .accessibilityIdentifier("garden.addPlant")
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddPlantSheet { name, tolerance in
                    _ = try? store.addPlant(name: name, toleranceCelsius: tolerance)
                    reloadPlants()
                    viewModel.reevaluate()
                }
            }
            .sheet(isPresented: $isShowingLocationSheet) {
                LocationSheet(latitude: $latitude, longitude: $longitude) {
                    Task { await viewModel.refresh(latitude: latitude, longitude: longitude) }
                }
            }
            .refreshable {
                await viewModel.refresh(latitude: latitude, longitude: longitude)
            }
            .task {
                reloadPlants()
                await viewModel.refresh(latitude: latitude, longitude: longitude)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var tonightSection: some View {
        Section {
            if let min = viewModel.tonightMinC {
                HStack {
                    Text("Tonight's low")
                    Spacer()
                    Text(String(format: "%.1f °C", min))
                        .font(.title3.weight(.semibold))
                        .accessibilityIdentifier("garden.tonightLow")
                }
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.secondary)
            } else {
                Text("Fetching forecast…").foregroundStyle(.secondary)
            }

            if case .cache(let fetchedAt) = viewModel.dataSource {
                Label(
                    "Offline — using forecast from \(fetchedAt.formatted(.relative(presentation: .named)))",
                    systemImage: "wifi.slash"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var verdictSection: some View {
        Section("Your plants") {
            if plants.isEmpty {
                Text("Add a plant to get a nightly verdict.")
                    .foregroundStyle(.secondary)
            } else if viewModel.verdicts.isEmpty {
                ForEach(plants) { plant in
                    Text(plant.name)
                }
            } else {
                ForEach(viewModel.verdicts) { verdict in
                    VerdictRow(verdict: verdict)
                }
                .onDelete(perform: deletePlants)
            }
        }
    }

    // MARK: - Actions

    private func reloadPlants() {
        plants = (try? store.plants()) ?? []
    }

    private func deletePlants(at offsets: IndexSet) {
        let sortedPlants = (try? store.plants()) ?? []
        // Verdicts are sorted by risk; map back to the plant by id.
        for index in offsets {
            let verdict = viewModel.verdicts[index]
            if let plant = sortedPlants.first(where: { $0.id == verdict.id }) {
                _ = try? store.deletePlant(plant)
            }
        }
        reloadPlants()
        viewModel.reevaluate()
    }
}

// MARK: - Rows

private struct VerdictRow: View {
    let verdict: PlantVerdict

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(riskColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(verdict.plantName).font(.body)
                Text(verdict.advice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%+.1f°", verdict.marginC))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("garden.verdict.\(verdict.plantName)")
    }

    private var riskColor: Color {
        switch verdict.risk {
        case .none: return .green
        case .watch: return .yellow
        case .frost: return .orange
        case .hardFreeze: return .red
        @unknown default: return .gray
        }
    }
}

// MARK: - Sheets

private struct AddPlantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var tolerance: Double = 0

    let onAdd: (String, Double) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Plant name", text: $name)
                    .accessibilityIdentifier("addPlant.nameField")

                VStack(alignment: .leading) {
                    Text("Cold tolerance: \(String(format: "%.0f", tolerance)) °C")
                    Slider(value: $tolerance, in: -20...10, step: 1)
                        .accessibilityIdentifier("addPlant.toleranceSlider")
                    Text("The lowest temperature it tolerates uncovered. Tender plants: around 0°. Hardy perennials: −15° or lower.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Plant")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name.trimmingCharacters(in: .whitespaces), tolerance)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("addPlant.confirm")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct LocationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var latitude: Double
    @Binding var longitude: Double

    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Latitude") {
                        TextField("Latitude", value: $latitude, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Longitude") {
                        TextField("Longitude", value: $longitude, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Coordinates only — Frost Sentinel never asks for location permission, so your position is never shared with anyone. Find yours on any map app.")
                }
            }
            .navigationTitle("Location")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
