//-------------------------------------------------------------------------------------
// FragInputs
// This structure gather all possible varying/interpolator for this shader.
//-------------------------------------------------------------------------------------

#include "HDRenderPipeline/Debug/DebugViewMaterial.cs.hlsl"

struct FragInputs
{
    // Contain value return by SV_POSITION (That is name positionCS in PackedVarying).
    // xy: unormalized screen position (offset by 0.5), z: device depth, w: depth in view space
    // Note: SV_POSITION is the result of the clip space position provide to the vertex shaders that is transform by the viewport
    float4 unPositionSS; // In case depth offset is use, positionWS.w is equal to depth offset
    float3 positionWS;
    float2 texCoord0;
    float2 texCoord1;
    float2 texCoord2;
    float2 texCoord3;
    float3 tangentToWorld[3]; // These 3 vectors are normalized (no need for the material to normalize) and these are only for UVSet 0
    float4 color; // vertex color

    // For two sided lighting
    bool isFrontFace;

#ifdef SURFACE_GRADIENT
    // cached bump globals reusable for all possible UVs including procedural
    float3 sigmaX;
    float3 sigmaY;
    float3 vtxNormalWS; // Normalized
    float flipSign;

    // used for vertex level tangent space only (support on one UV set only)
    // TODO: Question Morten: Can I still use this one for POM ?
    float3 mikktsTang;
    float3 mikktsBino;

    // Use for the 3 other UVSet;
    float3 vT1, vB1;
    float3 vT2, vB2;
    float3 vT3, vB3;
#endif
};

// FragInputs use dir vector that are normalized in the code even if not used
// so we initialize them to a valid != 0 to shutdown compiler warning
FragInputs InitializeFragInputs()
{
    FragInputs output;
    ZERO_INITIALIZE(FragInputs, output);

    output.tangentToWorld[0] = float3(0.0, 0.0, 1.0);
    output.tangentToWorld[2] = float3(0.0, 0.0, 1.0);

    return output;
}

void GetVaryingsDataDebug(uint paramId, FragInputs input, inout float3 result, inout bool needLinearToSRGB)
{
    switch (paramId)
    {
    case DEBUGVIEWVARYING_TEXCOORD0:
        result = float3(input.texCoord0, 0.0);
        break;
    case DEBUGVIEWVARYING_TEXCOORD1:
        result = float3(input.texCoord1, 0.0);
        break;
    case DEBUGVIEWVARYING_TEXCOORD2:
        result = float3(input.texCoord2, 0.0);
        break;
    case DEBUGVIEWVARYING_TEXCOORD3:
        result = float3(input.texCoord3, 0.0);
        break;
    case DEBUGVIEWVARYING_VERTEX_TANGENT_WS:
        result = input.tangentToWorld[0].xyz * 0.5 + 0.5;
        break;
    case DEBUGVIEWVARYING_VERTEX_BITANGENT_WS:
        result = input.tangentToWorld[1].xyz * 0.5 + 0.5;
        break;
    case DEBUGVIEWVARYING_VERTEX_NORMAL_WS:
        result = input.tangentToWorld[2].xyz * 0.5 + 0.5;
        break;
    case DEBUGVIEWVARYING_VERTEX_COLOR:
        result = input.color.rgb; needLinearToSRGB = true;
        break;
    case DEBUGVIEWVARYING_VERTEX_COLOR_ALPHA:
        result = input.color.aaa;
        break;
    }
}
