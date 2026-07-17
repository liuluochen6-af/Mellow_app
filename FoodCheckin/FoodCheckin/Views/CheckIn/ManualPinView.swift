import SwiftUI
import MapKit

struct ManualPinView: View {
    @Binding var selectedPlace: SelectedPlace?
    var initialCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss
    @State private var pinCoordinate: CLLocationCoordinate2D
    @State private var placeName = ""
    @State private var cameraPosition: MapCameraPosition
    @StateObject private var locationService = LocationService()

    init(selectedPlace: Binding<SelectedPlace?>, initialCoordinate: CLLocationCoordinate2D?) {
        _selectedPlace = selectedPlace
        let coord = initialCoordinate ?? CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        _pinCoordinate = State(initialValue: coord)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("输入地点名称", text: $placeName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()

                ZStack {
                    Map(position: $cameraPosition) {
                        Annotation("", coordinate: pinCoordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                    .onMapCameraChange { context in
                        pinCoordinate = context.region.center
                    }

                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .navigationTitle("手动标注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") { confirmPin() }
                        .disabled(placeName.isEmpty)
                }
            }
        }
    }

    private func confirmPin() {
        Task {
            let geo = await locationService.reverseGeocode(coordinate: pinCoordinate)
            selectedPlace = SelectedPlace(
                name: placeName,
                placeId: nil,
                address: geo?.address ?? "",
                latitude: pinCoordinate.latitude,
                longitude: pinCoordinate.longitude,
                country: geo?.country ?? "",
                province: geo?.province ?? "",
                city: geo?.city ?? "",
                district: geo?.district ?? ""
            )
            dismiss()
        }
    }
}
