#ifndef __VP_EA_MATH_UTILS_MQH__
#define __VP_EA_MATH_UTILS_MQH__

double Clamp01(double v) { return (v < 0.0) ? 0.0 : (v > 1.0) ? 1.0 : v; }

#endif
