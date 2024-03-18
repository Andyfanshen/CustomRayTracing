#ifndef RT_RESTIR
#define RT_RESTIR

static const int MAX_TEMPORAL_REUSE = 15;
static const int MAX_SPATIAL_REUSE = 50;

struct RestirSample
{
    float3 viewPos, viewNormal;
    float3 samplePos, sampleNormal;
    float3 radiance;
};

struct Reservoir
{
    RestirSample sample;
    float w, M, Wout;
};

void ReservoirUpdate(inout Reservoir reservoir, RestirSample sample, float w, float rand)
{
    reservoir.w += w;
    reservoir.M += 1;

    if(reservoir.M > MAX_TEMPORAL_REUSE)
    {
        reservoir.w *= MAX_TEMPORAL_REUSE / reservoir.M;
        reservoir.M = MAX_TEMPORAL_REUSE;
    }

    if(rand < (w / reservoir.w))
    {
        reservoir.sample = sample;
    }

    reservoir.Wout = reservoir.w * rcp(reservoir.M * Luminance(reservoir.sample.radiance));
}

// Only used for reservoir_2.M == 1. i.e. temporal reuse.
void ReservoirMerge(inout Reservoir reservoir_1, in Reservoir reservoir_2, float rand)
{
    ReservoirUpdate(reservoir_1, reservoir_2.sample, Luminance(reservoir_2.sample.radiance) * reservoir_2.Wout, rand);
}

void ReservoirUpdate_spatial(inout Reservoir reservoir, RestirSample sample, float w, float rand)
{
    reservoir.w += w;
    reservoir.M += 1;

    if(reservoir.M > MAX_SPATIAL_REUSE)
    {
        reservoir.w *= MAX_SPATIAL_REUSE / reservoir.M;
        reservoir.M = MAX_SPATIAL_REUSE;
    }

    if(rand < (w / reservoir.w))
    {
        reservoir.sample = sample;
    }

    // Cannot compute Wout here, compute outside after all reservoirs merged.
    // reservoir.M = Sum(reservoirs);
    // reservoir.Wout = reservoir.w / (reservoir.M * Luminance(reservoir.sample.radiance));
}

void ReservoirMerge_spatial(inout Reservoir reservoir_1, in Reservoir reservoir_2, float rand)
{
    //float totalM = reservoir_1.M + reservoir_2.M;
    //ReservoirUpdate_spatial(reservoir_1, reservoir_2.sample, Luminance(reservoir_2.sample.radiance) * reservoir_2.Wout * reservoir_2.M, rand);
    ReservoirUpdate(reservoir_1, reservoir_2.sample, Luminance(reservoir_2.sample.radiance) * reservoir_2.Wout, rand);

    //if(totalM > MAX_SPATIAL_REUSE)
    //{
    //    reservoir_1.w *= MAX_SPATIAL_REUSE / totalM;
    //    reservoir_1.M = MAX_SPATIAL_REUSE;
    //}
    //else
    //{
    //    reservoir_1.M = totalM;
    //}

    //reservoir_1.Wout = reservoir_1.w / (reservoir_1.M * Luminance(reservoir_1.sample.radiance));
}
#endif