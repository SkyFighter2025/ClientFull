// ============================================================================
// GFX2_MISSILE_INSTANCE (thẻ 65, port từ TestServer 2026-07-25) — D3D9 hardware instancing
// mesh đạn opaque rigid. Xem GFX2_INSTANCING_PLAN.md (TestServer, tham khảo thiết kế S0-S4).
// File master: Client/EffectLib/shaders/MissileInstance.fx
// Runtime: <client>\Res-Eff\MissileInstance.fx (LoadEffectFromFile - plaintext, như Water2.fx).
//
// STAGE 0 = PASSTHROUGH (unlit, textured): chỉ transform theo ma trận per-instance +
// ViewProj rồi sample base texture. Lighting/fog/MODULATE-material để STAGE 2 (chưa làm).
//
// stream0 (per-vertex, native mesh decl): POSITION/NORMAL/TEXCOORD0.
// stream1 (per-instance, C++ dựng): 4 hàng m_matCombined = TEXCOORD1..4, m_cColor = TEXCOORD5.
// ============================================================================

float4x4 ViewProj;        // view * projection (uniform, set 1 lần/nhóm)
texture  BaseTex;

sampler2D sBase = sampler_state
{
    Texture   = <BaseTex>;
    // 137: KHÔNG ép filter/address — kế thừa device state hiện hành (user anisotropic + CLAMP
    // của AtumApplication), khớp filtering với draw FFP baseline. Ép LINEAR cứng sẽ LỆCH pixel
    // khi user bật anisotropic.
};

struct VS_Input
{
    // stream 0 — hình học mesh chia sẻ
    float3 pos    : POSITION;
    float3 normal : NORMAL;
    float2 uv     : TEXCOORD0;
    // stream 1 — dữ liệu per-instance (m_matCombined 4 hàng + màu)
    float4 wr0    : TEXCOORD1;
    float4 wr1    : TEXCOORD2;
    float4 wr2    : TEXCOORD3;
    float4 wr3    : TEXCOORD4;
    float4 color  : TEXCOORD5;
};

struct VS_Output
{
    float4 TPos  : POSITION;
    float2 uv    : TEXCOORD0;
    float4 color : TEXCOORD1; // truyền sẵn cho STAGE 2 (chưa dùng ở passthrough)
};

VS_Output VS_Instance(VS_Input vin)
{
    VS_Output vout;
    // dựng lại ma trận world (= m_matCombined, đã compose world) từ 4 hàng row-major
    float4x4 W = float4x4(vin.wr0, vin.wr1, vin.wr2, vin.wr3);
    float4 wpos = mul(float4(vin.pos, 1.0), W);
    vout.TPos  = mul(wpos, ViewProj);
    vout.uv    = vin.uv;
    vout.color = vin.color;
    return vout;
}

float4 PS_Instance(VS_Output input) : COLOR0
{
    // STAGE 0: passthrough — chỉ base texture (chưa lighting/MODULATE màu/fog).
    return tex2D(sBase, input.uv);
}

technique MissileInstance
{
    pass P0
    {
        VertexShader = compile vs_3_0 VS_Instance();
        PixelShader  = compile ps_3_0 PS_Instance();
        // 137: KHÔNG set state ở đây — Gfx3InstFlush (EffectRender.cpp) sở hữu TOÀN BỘ state
        // (ZENABLE per-group, ZWRITEENABLE/ALPHABLENDENABLE/SRCBLEND/DESTBLEND/FOGENABLE chung)
        // ngay TRƯỚC Begin(). Nếu pass tự set state ở đây, BeginPass() sẽ ÁP DỤNG đè lên state
        // flush vừa set (DONOTSAVESTATE chỉ bỏ save/restore, KHÔNG bỏ áp dụng state của pass)
        // — mọi item hoãn sẽ vẽ SAI (opaque ZWrite=TRUE thay vì additive ZWrite=FALSE).
    }
}
