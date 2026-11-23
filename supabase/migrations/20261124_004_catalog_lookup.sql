-- SPRINT 3. 002'den sonra uygulanır (003 olsa da olmasa da çalışır).
-- Canlı ortamda çalıştırmadan önce Metehan incelemeli; ekip onayı gerekir.
-- Kapsam: #30 GTIN ile ürün + etken madde sorgusu (katalog tarafı).
--
-- Dönen durumlar:
--   bulundu        ürün var, etken maddeleri var, inceleme bekleyen yok
--   katalogda_yok  GTIN kayıtlı değil ya da 14 haneli değil
--   needs_review   ürün var ama etken maddesi yok / inceleme bekliyor
-- katalogda_yok "güvenli" demek değil, "değerlendirilmedi" demek.
-- Etkileşim kontrolü burada yapılmıyor, o check_drug_risk()'te.
-- security invoker: katalog RLS'i aynen geçerli, anon çağıramaz.

create or replace function public.catalog_lookup(p_gtin text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_gtin text := btrim(coalesce(p_gtin, ''));
  v_product public.products%rowtype;
  v_ingredients jsonb;
  v_count int;
  v_review int;
  v_status text;
  v_reason text;
  v_message text;
begin
  -- products.gtin her zaman 14 hane, değilse tabloya hiç bakma
  if v_gtin !~ '^[0-9]{14}$' then
    return jsonb_build_object(
      'status', 'katalogda_yok',
      'gtin', v_gtin,
      'reason', 'gecersiz_gtin',
      'product', null,
      'ingredients', '[]'::jsonb,
      'ingredient_count', 0,
      'message', 'Kod 14 haneli bir barkod (GTIN) değil; katalogda aranmadı. '
                 'Ürün değerlendirilmedi, eczacınıza danışın.'
    );
  end if;

  select * into v_product from public.products where gtin = v_gtin;
  if not found then
    return jsonb_build_object(
      'status', 'katalogda_yok',
      'gtin', v_gtin,
      'reason', 'kayit_yok',
      'product', null,
      'ingredients', '[]'::jsonb,
      'ingredient_count', 0,
      'message', 'Bu barkod katalogda kayıtlı değil. Ürün değerlendirilmedi, '
                 'eczacınıza danışın.'
    );
  end if;

  -- etken maddeler (kombine ürünlerde birden fazla)
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', i.id,
      'name', coalesce(nullif(btrim(i.display_name), ''), i.normalized_name),
      'normalized_name', i.normalized_name,
      'atc_codes', to_jsonb(i.atc_codes),
      'needs_review', i.needs_review,
      'review_reason', i.review_reason
    ) order by coalesce(nullif(btrim(i.display_name), ''), i.normalized_name)), '[]'::jsonb),
    count(*),
    count(*) filter (where i.needs_review)
  into v_ingredients, v_count, v_review
  from public.product_ingredients pi
  join public.ingredients i on i.id = pi.ingredient_id
  where pi.product_gtin = v_gtin;

  if v_count = 0 then
    v_status  := 'needs_review';
    v_reason  := 'etken_madde_yok';
    v_message := 'Ürün katalogda var ama etken maddesi kayıtlı değil; '
                 'kontrol tamamlanamaz.';
  elsif v_review > 0 then
    v_status  := 'needs_review';
    v_reason  := 'etken_madde_inceleme_bekliyor';
    v_message := 'Ürün katalogda bulundu, ancak etken madde bilgisi inceleme '
                 'bekliyor; kontrol tamamlanamaz.';
  else
    v_status  := 'bulundu';
    v_reason  := null;
    v_message := 'Ürün katalogda bulundu. Etkileşim kontrolü ayrıca yapılır.';
  end if;

  if v_product.is_demo then
    v_message := 'DEMO kayıt. ' || v_message;
  end if;

  return jsonb_build_object(
    'status', v_status,
    'gtin', v_gtin,
    'reason', v_reason,
    'product', jsonb_build_object(
      'display_name', v_product.display_name,
      'atc_code', v_product.atc_code,
      'license_status', v_product.license_status,
      'is_demo', v_product.is_demo,
      'data_source', v_product.data_source
    ),
    'ingredients', v_ingredients,
    'ingredient_count', v_count,
    'message', v_message
  );
end;
$$;

comment on function public.catalog_lookup(text) is
  '#30: GTIN -> ürün + etken maddeler (bulundu / katalogda_yok / needs_review)';

revoke all on function public.catalog_lookup(text) from public, anon;
grant execute on function public.catalog_lookup(text) to authenticated;
