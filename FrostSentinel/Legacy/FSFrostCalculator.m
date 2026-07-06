//
//  FSFrostCalculator.m
//  FrostSentinel
//
//  See FSFrostCalculator.h for why this class is Objective-C on purpose.
//

#import "FSFrostCalculator.h"

static const double FSDefaultWatchMarginCelsius = 3.0;
static const double FSDefaultHardFreezeMarginCelsius = 3.0;

@implementation FSFrostCalculator

- (instancetype)init {
    return [self initWithWatchMarginCelsius:FSDefaultWatchMarginCelsius
                    hardFreezeMarginCelsius:FSDefaultHardFreezeMarginCelsius];
}

- (instancetype)initWithWatchMarginCelsius:(double)watchMargin
                   hardFreezeMarginCelsius:(double)hardFreezeMargin {
    self = [super init];
    if (self) {
        _watchMarginCelsius = watchMargin;
        _hardFreezeMarginCelsius = hardFreezeMargin;
    }
    return self;
}

- (double)marginForForecastMinCelsius:(double)forecastMinCelsius
                     toleranceCelsius:(double)toleranceCelsius {
    return forecastMinCelsius - toleranceCelsius;
}

- (FSFrostRisk)riskForForecastMinCelsius:(double)forecastMinCelsius
                        toleranceCelsius:(double)toleranceCelsius {
    double margin = [self marginForForecastMinCelsius:forecastMinCelsius
                                     toleranceCelsius:toleranceCelsius];

    if (margin > self.watchMarginCelsius) {
        return FSFrostRiskNone;
    }
    if (margin > 0.0) {
        return FSFrostRiskWatch;
    }
    if (margin > -self.hardFreezeMarginCelsius) {
        return FSFrostRiskFrost;
    }
    return FSFrostRiskHardFreeze;
}

- (NSString *)adviceForRisk:(FSFrostRisk)risk plantName:(NSString *)plantName {
    switch (risk) {
        case FSFrostRiskNone:
            return [NSString stringWithFormat:@"%@ is fine tonight.", plantName];
        case FSFrostRiskWatch:
            return [NSString stringWithFormat:@"Keep an eye on %@ — it's close to its limit tonight.", plantName];
        case FSFrostRiskFrost:
            return [NSString stringWithFormat:@"Cover %@ tonight.", plantName];
        case FSFrostRiskHardFreeze:
            return [NSString stringWithFormat:@"Bring %@ inside if you can — covering may not be enough.", plantName];
    }
    return [NSString stringWithFormat:@"%@ needs a look.", plantName];
}

@end
