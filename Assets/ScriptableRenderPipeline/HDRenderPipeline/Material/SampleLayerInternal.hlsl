
// These functions are use to hide the handling of triplanar mapping
// Normal need a specific treatment as they use special encoding for both base and detail map
// Also we use multiple inclusion to handle the various variation for lod and bias

// param can be unused, lod or bias
float4 ADD_FUNC_SUFFIX(SampleLayer)(TEXTURE2D_ARGS(layerTex, layerSampler), LayerUV layerUV, float3 triplanarWeights, float param)
{
    if (layerUV.isTriplanar)
    {
        float4 val = float4(0.0, 0.0, 0.0, 0.0);

        if (triplanarWeights.x > 0.0)
            val += triplanarWeights.x * SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvZY, param);
        if (triplanarWeights.y > 0.0)
            val += triplanarWeights.y * SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXZ, param);
        if (triplanarWeights.z > 0.0)
            val += triplanarWeights.z * SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXY, param);

        return val;
    }
    else
    {
        return SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uv, param);
    }
}

// TODO: Handle BC5 format, currently this code is for DXT5nm - After the change, rename this function UnpackNormalmapRGorAG
// This version is use for the base normal map
float3 ADD_FUNC_SUFFIX(SampleLayerNormal)(TEXTURE2D_ARGS(layerTex, layerSampler), LayerUV layerUV, float3 triplanarWeights, float scale, float param)
{
    if (layerUV.isTriplanar)
    {
        float3 val = float3(0.0, 0.0, 0.0);

        if (triplanarWeights.x > 0.0)
            val += triplanarWeights.x * UnpackNormalAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvZY, param), scale);
        if (triplanarWeights.y > 0.0)
            val += triplanarWeights.y * UnpackNormalAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXZ, param), scale);
        if (triplanarWeights.z > 0.0)
            val += triplanarWeights.z * UnpackNormalAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXY, param), scale);

#ifdef SURFACE_GRADIENT
        float2 deriv_xplane, float2 deriv_yplane, float2 deriv_zplane;
        deriv_xplane = deriv_yplane = deriv_zplane = float2(0.0, 0.0);

        if (triplanarWeights.x > 0.0)
            deriv_xplane = triplanarWeights.x * DerivativeAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvZY, param), scale);
        if (triplanarWeights.y > 0.0)
            deriv_yplane += triplanarWeights.y * DerivativeAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXZ, param), scale);
        if (triplanarWeights.z > 0.0)
            deriv_zplane += triplanarWeights.z * DerivativeAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXY, param), scale);

        float3 grad = float3(deriv_zplane.x + deriv_yplane.y, deriv_zplane.y + deriv_xplane.y, deriv_xplane.x + deriv_yplane.x);
        return surfgradFromVolumeGradient(layerUV.vertexNormalWS, grad);
#endif

        return normalize(val);
    }
    else
    {        
#ifdef SURFACE_GRADIENT
        float2 deriv = DerivativeAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uv, param), scale);
        return deriv.x * vT + deriv.y * vB;
#else
        return UnpackNormalAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uv, param), scale);
#endif
    }
}

// This version is for normalmap with AG encoding only. Mainly use with details map.
float3 ADD_FUNC_SUFFIX(SampleLayerNormalAG)(TEXTURE2D_ARGS(layerTex, layerSampler), LayerUV layerUV, float3 triplanarWeights, float scale, float param)
{
    if (layerUV.isTriplanar)
    {
        float3 val = float3(0.0, 0.0, 0.0);

        if (triplanarWeights.x > 0.0)
            val += triplanarWeights.x * UnpackNormalAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvZY, param), scale);
        if (triplanarWeights.y > 0.0)
            val += triplanarWeights.y * UnpackNormalAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXZ, param), scale);
        if (triplanarWeights.z > 0.0)
            val += triplanarWeights.z * UnpackNormalAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXY, param), scale);

        return normalize(val);
    }
    else
    {
        return UnpackNormalAG(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uv, param), scale);
    }
}

// This version is for normalmap with RGB encoding only, i.e uncompress or BC7. Mainly used for object space normal.
float3 ADD_FUNC_SUFFIX(SampleLayerNormalRGB)(TEXTURE2D_ARGS(layerTex, layerSampler), LayerUV layerUV, float3 triplanarWeights, float scale, float param)
{
    if (layerUV.isTriplanar)
    {
        float3 val = float3(0.0, 0.0, 0.0);

        if (triplanarWeights.x > 0.0)
            val += triplanarWeights.x * UnpackNormalRGB(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvZY, param), scale);
        if (triplanarWeights.y > 0.0)
            val += triplanarWeights.y * UnpackNormalRGB(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXZ, param), scale);
        if (triplanarWeights.z > 0.0)
            val += triplanarWeights.z * UnpackNormalRGB(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uvXY, param), scale);

        return normalize(val);
    }
    else
    {
        return UnpackNormalRGB(SAMPLE_TEXTURE_FUNC(layerTex, layerSampler, layerUV.uv, param), scale);
    }
}
