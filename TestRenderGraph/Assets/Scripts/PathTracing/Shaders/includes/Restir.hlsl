#ifndef RT_RESTIR
#define RT_RESTIR

static const float MAX_TEMPORAL_REUSE = 15;
static const float MAX_SPATIAL_REUSE = 50;

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

// reservoir   : empty reservoir
// reservoir_1 : neighbour reservoir
void ReservoirUpdate_spatial(inout Reservoir reservoir, Reservoir reservoir_1, float rand)
{
    float w = Luminance(reservoir_1.sample.radiance) * reservoir_1.Wout * reservoir_1.M;

    reservoir.w += w;
    reservoir.M += 1;

    if(reservoir.M > MAX_SPATIAL_REUSE)
    {
        reservoir.w *= MAX_SPATIAL_REUSE / reservoir.M;
        reservoir.M = MAX_SPATIAL_REUSE;
    }

    if(rand < (w / reservoir.w))
    {
        reservoir.sample = reservoir_1.sample;
    }
}
#endif