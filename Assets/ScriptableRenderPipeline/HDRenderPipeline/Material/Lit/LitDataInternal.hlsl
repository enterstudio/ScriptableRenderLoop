void ADD_IDX(ComputeLayerTexCoord)( float2 texCoord0, float2 texCoord1, float2 texCoord2, float2 texCoord3,
                                    float3 positionWS, float3 vertexNormalWS, bool isPlanar, bool isTriplanar, float worldScale, inout LayerTexCoord layerTexCoord, float additionalTiling = 1.0)
{
    // Handle uv0, uv1, uv2, uv3 based on _UVMappingMask weight (exclusif 0..1)
    float2 uvBase = ADD_IDX(_UVMappingMask).x * texCoord0 +
                    ADD_IDX(_UVMappingMask).y * texCoord1 + 
                    ADD_IDX(_UVMappingMask).z * texCoord2 +
                    ADD_IDX(_UVMappingMask).w * texCoord3;

    // Only used with layered, allow to have additional tiling
    uvBase *= additionalTiling.xx;
                    

    float2 uvDetails =  ADD_IDX(_UVDetailsMappingMask).x * texCoord0 +
                        ADD_IDX(_UVDetailsMappingMask).y * texCoord1 +
                        ADD_IDX(_UVDetailsMappingMask).z * texCoord2 +
                        ADD_IDX(_UVDetailsMappingMask).w * texCoord3;

    // If base is planar/triplanar then detail map is forced to be planar/triplanar
    ADD_IDX(layerTexCoord.base).isPlanar = isPlanar;
    ADD_IDX(layerTexCoord.base).isTriplanar = isTriplanar;
    ADD_IDX(layerTexCoord.details).isPlanar = isPlanar;
    ADD_IDX(layerTexCoord.details).isTriplanar = isTriplanar;

    // TODO: Currently we only handle world planar/triplanar but we may want local planar/triplanar.
    // In this case both position and normal need to be convert to object space.

    // planar/triplanar
    float2 uvXZ;
    float2 uvXY;
    float2 uvZY;
    GetTriplanarCoordinate(positionWS * worldScale, vertexNormalWS, uvXZ, uvXY, uvZY);
 
    if (isPlanar)
    {
        uvBase = uvDetails = uvXZ;
    }

    // Apply tiling options
    ADD_IDX(layerTexCoord.base).uv = TRANSFORM_TEX(uvBase, ADD_IDX(_BaseColorMap));
    ADD_IDX(layerTexCoord.details).uv = TRANSFORM_TEX(uvDetails, ADD_IDX(_DetailMap));

    ADD_IDX(layerTexCoord.base).uvXZ = TRANSFORM_TEX(uvXZ, ADD_IDX(_BaseColorMap));
    ADD_IDX(layerTexCoord.base).uvXY = TRANSFORM_TEX(uvXY, ADD_IDX(_BaseColorMap));
    ADD_IDX(layerTexCoord.base).uvZY = TRANSFORM_TEX(uvZY, ADD_IDX(_BaseColorMap));        

    ADD_IDX(layerTexCoord.details).uvXZ = TRANSFORM_TEX(uvXZ, ADD_IDX(_DetailMap));
    ADD_IDX(layerTexCoord.details).uvXY = TRANSFORM_TEX(uvXY, ADD_IDX(_DetailMap));
    ADD_IDX(layerTexCoord.details).uvZY = TRANSFORM_TEX(uvZY, ADD_IDX(_DetailMap));

    #ifdef SURFACE_GRADIENT
    // TODO: ask morten, should I provide uv corrdiante after transform here or texcoord are enough ?
    // TODO: Need input here! What can we do when this code is call from tessellation ? No normal map in this case, need a specific bool
    ADD_IDX(layerTexCoord.base).vB =    ADD_IDX(_UVMappingMask).x * input.mikktB +
                                        ADD_IDX(_UVMappingMask).y * input.vB1 +
                                        ADD_IDX(_UVMappingMask).z * input.vB2 +
                                        ADD_IDX(_UVMappingMask).w * input.vB3;

    //

    ADD_IDX(layerTexCoord.base).vertexNormalWS = vertexNormalWS;
    ADD_IDX(layerTexCoord.details).vertexNormalWS = vertexNormalWS;
    #endif
}

float3 ADD_IDX(GetNormalTS)(FragInputs input, LayerTexCoord layerTexCoord, float3 detailNormalTS, float detailMask, bool useBias, float bias)
{
    float3 normalTS;

#ifdef _NORMALMAP_IDX
    #ifdef _NORMALMAP_TANGENT_SPACE_IDX
    if (useBias)
    {
        normalTS = SAMPLE_LAYER_NORMALMAP_BIAS(ADD_IDX(_NormalMap), ADD_ZERO_IDX(sampler_NormalMap), ADD_IDX(layerTexCoord.base), ADD_IDX(_NormalScale), bias);
    }
    else
    {
        normalTS = SAMPLE_LAYER_NORMALMAP(ADD_IDX(_NormalMap), ADD_ZERO_IDX(sampler_NormalMap), ADD_IDX(layerTexCoord.base), ADD_IDX(_NormalScale));
    }            
    #else // Object space
    // to be able to combine object space normal with detail map we transform it to tangent space (object space normal composition is complex operation).
    // then later we will re-transform it to world space.
    if (useBias)
    {
        float3 normalOS = SAMPLE_LAYER_NORMALMAP_RGB_BIAS(ADD_IDX(_NormalMap), ADD_ZERO_IDX(sampler_NormalMap), ADD_IDX(layerTexCoord.base), ADD_IDX(_NormalScale), bias).rgb;
        #ifdef SURFACE_GRADIENT
        // TODO: What can I do here, I need a way to know I am object space normal inside SAMPLE_LAYER_NORMALMAP_RGB_BIAS
        // then call surfgradFromPerturbedNormal. But how do I call the triplanar as I need derivative there...
        // or do I lerp grad based on blend weight, then call surfgradFromVolumeGradient ?
        normalTS = normalOS;
        #else
        normalTS = TransformObjectToTangent(normalOS, input.tangentToWorld);
        #endif
    }
    else
    {
        float3 normalOS = SAMPLE_LAYER_NORMALMAP_RGB(ADD_IDX(_NormalMap), ADD_ZERO_IDX(sampler_NormalMap), ADD_IDX(layerTexCoord.base), ADD_IDX(_NormalScale)).rgb;
        #ifdef SURFACE_GRADIENT
        normalTS = normalOS;
        #else
        normalTS = TransformObjectToTangent(normalOS, input.tangentToWorld);
        #endif
    }
    #endif

    #ifdef _DETAIL_MAP_IDX
    
    #ifdef SURFACE_GRADIENT
    normalTS += detailNormalTS;
    #else
    normalTS = lerp(normalTS, BlendNormalRNM(normalTS, detailNormalTS), detailMask);
    #endif

    #endif
#else

    #ifdef SURFACE_GRADIENT
    normalTS = float3(0.0, 0.0, 0.0); // No gradient for vtxNormal
    #else
    normalTS = float3(0.0, 0.0, 1.0);
    #endif

#endif

    // TODO: Ask Morten: Does it work by flipping gradient ? What about mirroring ?

#if defined(_DOUBLESIDED_LIGHTING_FLIP) || defined(_DOUBLESIDED_LIGHTING_MIRROR)
    #ifdef _DOUBLESIDED_LIGHTING_FLIP
    float3 oppositeNormalTS = -normalTS;
    #else
    // Mirror the normal with the plane define by vertex normal
    float3 oppositeNormalTS = reflect(normalTS, float3(0.0, 0.0, 1.0)); // Reflect around vertex normal (in tangent space this is z)
    #endif
    // TODO : Test if GetOddNegativeScale() is necessary here in case of normal map, as GetOddNegativeScale is take into account in CreateTangentToWorld();
    normalTS = input.isFrontFace ?
                    (GetOddNegativeScale() >= 0.0 ? normalTS : oppositeNormalTS) :
                    (-GetOddNegativeScale() >= 0.0 ? normalTS : oppositeNormalTS);
#endif

    return normalTS;
}

// Return opacity
float ADD_IDX(GetSurfaceData)(FragInputs input, LayerTexCoord layerTexCoord, out SurfaceData surfaceData, out float3 normalTS)
{
    float alpha = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_BaseColorMap), ADD_ZERO_IDX(sampler_BaseColorMap), ADD_IDX(layerTexCoord.base)).a * ADD_IDX(_BaseColor).a;

    // Perform alha test very early to save performance (a killed pixel will not sample textures)
#if defined(_ALPHATEST_ON) && !defined(LAYERED_LIT_SHADER)
    clip(alpha - _AlphaCutoff);
#endif

    float3 detailNormalTS = float3(0.0, 0.0, 0.0);
    float detailMask = 0.0;
#ifdef _DETAIL_MAP_IDX
    detailMask = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_DetailMask), ADD_ZERO_IDX(sampler_DetailMask), ADD_IDX(layerTexCoord.base)).g;
    float2 detailAlbedoAndSmoothness = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_DetailMap), ADD_ZERO_IDX(sampler_DetailMap), ADD_IDX(layerTexCoord.details)).rb;
    float detailAlbedo = detailAlbedoAndSmoothness.r;
    float detailSmoothness = detailAlbedoAndSmoothness.g;
    // Resample the detail map but this time for the normal map. This call should be optimize by the compiler
    // We split both call due to trilinear mapping
    detailNormalTS = SAMPLE_LAYER_NORMALMAP_AG(ADD_IDX(_DetailMap), ADD_ZERO_IDX(sampler_DetailMap), ADD_IDX(layerTexCoord.details), ADD_ZERO_IDX(_DetailNormalScale));
#endif

    surfaceData.baseColor = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_BaseColorMap), ADD_ZERO_IDX(sampler_BaseColorMap), ADD_IDX(layerTexCoord.base)).rgb * ADD_IDX(_BaseColor).rgb;
#ifdef _DETAIL_MAP_IDX
    surfaceData.baseColor *= LerpWhiteTo(2.0 * saturate(detailAlbedo * ADD_IDX(_DetailAlbedoScale)), detailMask);
#endif

#ifdef _SPECULAROCCLUSIONMAP_IDX
    // TODO: Do something. For now just take alpha channel
    surfaceData.specularOcclusion = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_SpecularOcclusionMap), ADD_ZERO_IDX(sampler_SpecularOcclusionMap), ADD_IDX(layerTexCoord.base)).a;
#else
    // The specular occlusion will be perform outside the internal loop
    surfaceData.specularOcclusion = 1.0;
#endif
    surfaceData.normalWS = float3(0.0, 0.0, 0.0); // Need to init this to keep quiet the compiler, but this is overriden later (0, 0, 0) so if we forget to override the compiler may comply.

    // TODO: think about using BC5
    normalTS = ADD_IDX(GetNormalTS)(input, layerTexCoord, detailNormalTS, detailMask, false, 0.0);

#if defined(_MASKMAP_IDX)
    surfaceData.perceptualSmoothness = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_MaskMap), ADD_ZERO_IDX(sampler_MaskMap), ADD_IDX(layerTexCoord.base)).a;
#else
    surfaceData.perceptualSmoothness = 1.0;
#endif
    surfaceData.perceptualSmoothness *= ADD_IDX(_Smoothness);
#ifdef _DETAIL_MAP_IDX
    surfaceData.perceptualSmoothness *= LerpWhiteTo(2.0 * saturate(detailSmoothness * ADD_IDX(_DetailSmoothnessScale)), detailMask);
#endif

    // MaskMap is RGBA: Metallic, Ambient Occlusion (Optional), emissive Mask (Optional), Smoothness
#ifdef _MASKMAP_IDX
    surfaceData.metallic = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_MaskMap), ADD_ZERO_IDX(sampler_MaskMap), ADD_IDX(layerTexCoord.base)).r;
    surfaceData.ambientOcclusion = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_MaskMap), ADD_ZERO_IDX(sampler_MaskMap), ADD_IDX(layerTexCoord.base)).g;
#else
    surfaceData.metallic = 1.0;
    surfaceData.ambientOcclusion = 1.0;
#endif
    surfaceData.metallic *= ADD_IDX(_Metallic);

    // This part of the code is not used in case of layered shader but we keep the same macro system for simplicity
#if !defined(LAYERED_LIT_SHADER)

    surfaceData.materialId = _MaterialID;

    // TODO: think about using BC5
#ifdef _TANGENTMAP
#ifdef _NORMALMAP_TANGENT_SPACE_IDX // Normal and tangent use same space
    float3 tangentTS = SAMPLE_LAYER_NORMALMAP(ADD_IDX(_TangentMap), ADD_ZERO_IDX(sampler_TangentMap), ADD_IDX(layerTexCoord.base), 1.0);
    surfaceData.tangentWS = TransformTangentToWorld(tangentTS, input.tangentToWorld);
#else // Object space
    float3 tangentOS = SAMPLE_LAYER_NORMALMAP_RGB(ADD_IDX(_TangentMap), ADD_ZERO_IDX(sampler_TangentMap), ADD_IDX(layerTexCoord.base), 1.0).rgb;
    surfaceData.tangentWS = TransformObjectToWorldDir(tangentOS);
#endif
#else
    surfaceData.tangentWS = input.tangentToWorld[0].xyz;
#endif
    // TODO: Is there anything todo regarding flip normal but for the tangent ?

#ifdef _ANISOTROPYMAP
    surfaceData.anisotropy = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_AnisotropyMap), ADD_ZERO_IDX(sampler_AnisotropyMap), ADD_IDX(layerTexCoord.base)).b;
#else
    surfaceData.anisotropy = 1.0;
#endif
    surfaceData.anisotropy *= ADD_IDX(_Anisotropy);

    surfaceData.specular = 0.04;

    surfaceData.subsurfaceProfile = _SubsurfaceProfile;
#ifdef _SUBSURFACE_RADIUS_MAP
	surfaceData.subsurfaceRadius = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_SubsurfaceRadiusMap), ADD_ZERO_IDX(sampler_SubsurfaceRadiusMap), ADD_IDX(layerTexCoord.base)).r * _SubsurfaceRadius;
#else
    surfaceData.subsurfaceRadius = _SubsurfaceRadius;
#endif
    surfaceData.subsurfaceProfile = 0;

#ifdef _THICKNESS_MAP
	surfaceData.thickness = SAMPLE_LAYER_TEXTURE2D(ADD_IDX(_ThicknessMap), ADD_ZERO_IDX(sampler_ThicknessMap), ADD_IDX(layerTexCoord.base)).r;
#else
    surfaceData.thickness = _Thickness;
#endif

    surfaceData.coatNormalWS = float3(1.0, 0.0, 0.0);
    surfaceData.coatPerceptualSmoothness = 1.0;
    surfaceData.specularColor = float3(0.0, 0.0, 0.0);

#else // #if !defined(LAYERED_LIT_SHADER)

    // Mandatory to setup value to keep compiler quiet

    // Layered shader only support materialId 0
    surfaceData.materialId = 0;

    surfaceData.tangentWS = input.tangentToWorld[0].xyz;
    surfaceData.anisotropy = 0;
    surfaceData.specular = 0.04;

    surfaceData.subsurfaceRadius = 1.0;
    surfaceData.thickness = 0.0;
    surfaceData.subsurfaceProfile = 0;

    surfaceData.coatNormalWS = float3(1.0, 0.0, 0.0);
    surfaceData.coatPerceptualSmoothness = 1.0;
    surfaceData.specularColor = float3(0.0, 0.0, 0.0);

#endif // #if !defined(LAYERED_LIT_SHADER)

    return alpha;
}

