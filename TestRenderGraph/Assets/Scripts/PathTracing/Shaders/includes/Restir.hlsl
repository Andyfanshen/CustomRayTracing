#ifndef RT_RESTIR
#define RT_RESTIR

static const int MAX_TEMPORAL_REUSE = 5;
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

    reservoir.Wout = reservoir.w / (reservoir.M * Luminance(reservoir.sample.radiance));
}

void ReservoirMerge(inout Reservoir reservoir_1, in Reservoir reservoir_2, float p, float rand)
{
    ReservoirUpdate(reservoir_1, reservoir_2.sample, p * reservoir_2.Wout * reservoir_2.M, rand);
    reservoir_1.M = min(MAX_TEMPORAL_REUSE, reservoir_1.M + reservoir_2.M);
}

void ReservoirUpdate_spatial(inout Reservoir reservoir, RestirSample sample, int count, float w, float rand)
{
    reservoir.w += w;
    reservoir.M += count;

    if(reservoir.M > MAX_SPATIAL_REUSE)
    {
        reservoir.w *= MAX_SPATIAL_REUSE / reservoir.M;
        reservoir.M = MAX_SPATIAL_REUSE;
    }

    if(rand < w / reservoir.w)
    {
        reservoir.sample = sample;
    }
}

void ReservoirMerge_spatial(inout Reservoir reservoir_1, in Reservoir reservoir_2, float p, float rand)
{
    ReservoirUpdate_spatial(reservoir_1, reservoir_2.sample, reservoir_2.M, p * reservoir_2.Wout * reservoir_2.M, rand);
    reservoir_1.M = min(MAX_SPATIAL_REUSE, reservoir_1.M + reservoir_2.M);
}
#endif