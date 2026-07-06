//
//  FSFrostCalculator.h
//  FrostSentinel
//
//  Frost-risk classification, written in Objective-C.
//
//  Why Objective-C? Deliberately. Horticultural and agricultural calculation
//  libraries in the real world are frequently legacy code, and contract work
//  means maintaining and bridging code like this rather than rewriting it.
//  This class demonstrates Swift/Objective-C interop: an NS_ENUM bridged into
//  Swift, nullability annotations, and a small, well-documented legacy surface
//  consumed by modern async Swift.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The frost risk for a single plant on a single night.
typedef NS_ENUM(NSInteger, FSFrostRisk) {
    /// Forecast minimum is comfortably above the plant's cold tolerance.
    FSFrostRiskNone = 0,
    /// Forecast minimum is within the watch margin of the plant's tolerance.
    FSFrostRiskWatch = 1,
    /// Forecast minimum is at or below the plant's tolerance. Cover it.
    FSFrostRiskFrost = 2,
    /// Forecast minimum is far below tolerance. Covering may not be enough.
    FSFrostRiskHardFreeze = 3,
};

@interface FSFrostCalculator : NSObject

/// The margin (in °C) above a plant's tolerance at which we start warning.
/// Forecasts are imprecise; a night forecast within this margin deserves
/// attention even though it is nominally "safe".
@property (nonatomic, readonly) double watchMarginCelsius;

/// The margin (in °C) below a plant's tolerance at which covering the plant
/// is unlikely to be enough protection.
@property (nonatomic, readonly) double hardFreezeMarginCelsius;

- (instancetype)init;
- (instancetype)initWithWatchMarginCelsius:(double)watchMargin
                   hardFreezeMarginCelsius:(double)hardFreezeMargin NS_DESIGNATED_INITIALIZER;

/// Classifies the risk for one plant on one night.
///
/// @param forecastMinCelsius The forecast overnight minimum temperature.
/// @param toleranceCelsius   The lowest temperature the plant tolerates unprotected.
- (FSFrostRisk)riskForForecastMinCelsius:(double)forecastMinCelsius
                        toleranceCelsius:(double)toleranceCelsius;

/// A short, calm, user-facing recommendation for a risk level.
/// The tone is deliberate: no alarm, just what to do.
- (NSString *)adviceForRisk:(FSFrostRisk)risk plantName:(NSString *)plantName;

/// The margin, in °C, between the forecast and the plant's tolerance.
/// Positive means safe headroom; negative means the forecast dips below tolerance.
- (double)marginForForecastMinCelsius:(double)forecastMinCelsius
                     toleranceCelsius:(double)toleranceCelsius;

@end

NS_ASSUME_NONNULL_END
