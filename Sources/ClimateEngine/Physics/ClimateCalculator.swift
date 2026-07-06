import Foundation

public enum ClimateCalculator {

    /// Calculates the saturation vapor pressure in hPa.
    /// Formula: Magnus approximation over water.
    public static func saturationVaporPressure(temperatureCelsius: Double) -> Double {
        6.112 * exp((17.62 * temperatureCelsius) / (243.12 + temperatureCelsius))
    }

    /// Calculates the actual vapor pressure in hPa.
    public static func vaporPressure(
        temperatureCelsius: Double,
        relativeHumidity: Double
    ) -> Double {
        saturationVaporPressure(temperatureCelsius: temperatureCelsius) * relativeHumidity / 100.0
    }

    /// Calculates the dew point in °C.
    public static func dewPoint(
        temperatureCelsius: Double,
        relativeHumidity: Double
    ) -> Double {
        let gamma = log(relativeHumidity / 100.0) +
            (17.62 * temperatureCelsius) / (243.12 + temperatureCelsius)

        return (243.12 * gamma) / (17.62 - gamma)
    }

    /// Calculates absolute humidity in g/m³.
    public static func absoluteHumidity(
        temperatureCelsius: Double,
        relativeHumidity: Double
    ) -> Double {
        let vaporPressureHPa = vaporPressure(
            temperatureCelsius: temperatureCelsius,
            relativeHumidity: relativeHumidity
        )

        return 216.7 * vaporPressureHPa / (temperatureCelsius + 273.15)
    }
}
