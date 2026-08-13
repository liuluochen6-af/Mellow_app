import SwiftUI
import MapKit

struct SelectedPlace: Equatable {
    var name: String
    var placeId: String?
    var address: String
    var latitude: Double
    var longitude: Double
    var country: String
    var province: String
    var city: String
    var district: String
}

struct LocationSearchView: View {
    @Binding var selectedPlace: SelectedPlace?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()
    @State private var searchText = ""
    @State private var showManualPin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索店铺名称", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                .onChange(of: searchText) { _, newValue in
                    Task {
                        await locationService.search(query: newValue, near: locationService.currentLocation)
                    }
                }

                if locationService.isSearching {
                    ProgressView().padding()
                }

                List {
                    if !locationService.searchResults.isEmpty {
                        ForEach(locationService.searchResults, id: \.self) { item in
                            Button {
                                selectMapItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "未知地点")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(item.placemark.title ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            showManualPin = true
                        } label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("在地图上手动标注")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("选择地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                locationService.requestPermission()
            }
            .sheet(isPresented: $showManualPin) {
                ManualPinView(selectedPlace: $selectedPlace, initialCoordinate: locationService.currentLocation)
            }
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let placemark = item.placemark
        let country = placemark.country ?? ""
        let province = placemark.administrativeArea ?? ""
        let city = CityRegionNormalizer.cityName(
            country: country,
            province: province,
            locality: placemark.locality ?? "",
            coordinate: coordinate
        )

        selectedPlace = SelectedPlace(
            name: item.name ?? "未知地点",
            placeId: nil,
            address: placemark.title ?? "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            country: country,
            province: province,
            city: city,
            district: placemark.subLocality ?? ""
        )
        dismiss()
    }
}
