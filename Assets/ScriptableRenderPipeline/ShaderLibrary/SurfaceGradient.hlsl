// this produces an orthonormal basis of the tangent and bitangent WITHOUT vertex level tangent/bitangent for any UV including procedurally generated
// method released with the demo for publication of "bump mapping unparametrized surfaces on the GPU"
// http://mmikkelsen3d.blogspot.com/2011/07/derivative-maps.html
void genBasisTB(float3 nrmVertexNormal, float3 sigmaX, float3 sigmaY, float flip sign, out float3 vT, out float3 vB, float2 texST)
{
    float2 dSTdx = ddx_fine(texST), dSTdy = ddy_fine(texST);

    float det = dot(dSTdx, float2(dSTdy.y, -dSTdy.x));
    float sign_det = det < 0 ? -1 : 1;

    // invC0 represents (dXds, dYds); but we don't divide by determinant (scale by sign instead)
    float2 invC0 = sign_det * float2(dSTdy.y, -dSTdx.y);
    vT = sigmaX * invC0.x + sigmaY * invC0.y;
    if (abs(det) > 0.0) 
        vT = normalize(vT);
    vB = (sign_det * flip_sign) * cross(nrmVertexNormal, vT);
}

// surface gradient from an on the fly TBN (deriv obtained using tspaceNormalToDerivative())
float3 surfgradFromOnTheFlyTBN(float2 deriv, float3 vT, float3 vB)
{
    return deriv.x * vT + deriv.y * vB;
}

// surface gradient from conventional vertex level TBN (mikktspace compliant and deriv obtained using tspaceNormalToDerivative())
float3 surfgradFromConventionalTBN(float2 deriv)
{
    return deriv.x * mikktsTang + deriv.y * mikktsBino;
}

// surface gradient from an already generated "normal" such as from an object space normal map
// this allows us to mix the contribution together with a series of other contributions including tangent space normals
// v does not need to be unit length as long as it establishes the direction.
float3 surfgradFromPerturbedNormal(float3 nrmVertexNormal, float3 v)
{
    float3 n = nrmVertexNormal;
    float s = 1.0 / max(FLT_EPSILON, abs(dot(n, v)));
    return s * (dot(n, v) * n - v);
}

// used to produce a surface gradient from the gradient of a volume bump function such as a volume of perlin noise.
// equation 2. in "bump mapping unparametrized surfaces on the GPU".
// Observe the difference in figure 2. between using the gradient vs. the surface gradient to do bump mapping (the original method is proved wrong in the paper!).
float3 surfgradFromVolumeGradient(float3 nrmVertexNormal, float3 grad)
{
    return grad - dot(nrmVertexNormal, grad) * nrmVertexNormal;
}

// triplanar projection considered special case of volume bump map
// described here:  http://mmikkelsen3d.blogspot.com/2013/10/volume-height-maps-and-triplanar-bump.html
// derivs obtained using tspaceNormalToDerivative() and weights using computeTriplanarWeights().
float3 surfgradFromTriplanarProjection(float3 triplanarWeights, float2 deriv_xplane, float2 deriv_yplane, float2 deriv_zplane)
{
    const float w0 = triplanarWeights.x, w1 = triplanarWeights.y, w2 = triplanarWeights.z;

    // assume deriv_xplane, deriv_yplane and deriv_zplane sampled using (z,y), (z,x) and (x,y) respectively.
    // positive scales of the look-up coordinate will work as well but for negative scales the derivative components will need to be negated accordingly.
    float3 grad = float3(w2 * deriv_zplane.x + w1 * deriv_yplane.y, w2 * deriv_zplane.y + w0 * deriv_xplane.y, w0 * deriv_xplane.x + w1 * deriv_yplane.x);

    return surfgradFromVolumeGradient(grad);
}

float3 resolveNormalFromSurfaceGradient(float3 nrmVertexNormal, float3 surfGrad0)
{
    return normalize(nrmVertexNormal - surfGrad0);
}

float3 resolveNormalFromSurfaceGradients2(float3 nrmVertexNormal, float3 surfGrad0, float3 surfGrad1)
{
    return normalize(nrmVertexNormal - surfGrad0 - surfGrad1);
}

float3 resolveNormalFromSurfaceGradients3(float3 nrmVertexNormal, float3 surfGrad0, float3 surfGrad1, float3 surfGrad2)
{
    return normalize(nrmVertexNormal - surfGrad0 - surfGrad1 - surfGrad2);
}

float3 applyBumpScale(float scale, float3 surfgrad)    // must be valid surface gradient such as outlined above
{
    return scale * surfgrad;
}

float2 applyBumpScale(float scale, float2 deriv)    // deriv obtained using tspaceNormalToDerivative()
{
    return scale * deriv;
}

// input: vT is channels .xy of a tangent space normal in [-1;1]
// out: convert vT to a derivative
float2 tspaceNormalToDerivative(float2 vT)
{
    const float fS = 1.0 / (128 * 128);
    float2 vTsq = vT * vT;
    float nz_sq = 1 - vTsq.x - vTsq.y;
    float maxcompxy_sq = fS * max(vTsq.x, vTsq.y);
    float z_inv = rsqrt(max(nz_sq, maxcompxy_sq));

    return -z_inv * float2(vT.x, vT.y);
}

// The 128 means the derivative will come out no greater than 128 numerically (where 1 is 45 degrees so 128 is very steap). You can increase it if u like of course
// Basically tan(angle) limited to 128
// So a max angle of 89.55 degrees ;) id argue thats close enough to the vertical limit at 90 degrees

float2 DerivativeAG(float4 packedNormal, float scale = 1.0)
{
    float2 normalTSxy = packedNormal.wy * 2.0 - 1.0;
    return tspaceNormalToDerivative(normalTSxy) * scale;
}