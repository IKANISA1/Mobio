-- Expand countries table with USSD/MoMo data for 26 African markets
ALTER TABLE public.countries
  ADD COLUMN IF NOT EXISTS telecom_provider TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS momo_brand TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS ussd_number_format TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS ussd_code_format TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS currency_name TEXT NOT NULL DEFAULT '';

-- Upsert all 26 African markets + US/GB
INSERT INTO public.countries (id, name, flag, dialing_code, currency, currency_name, phone_placeholder, telecom_provider, momo_brand, ussd_number_format, ussd_code_format, sort_order, is_active) VALUES
  ('KE','Kenya','🇰🇪','+254','KES','Kenyan Shilling','712 345 678','Safaricom','M-Pesa','*334*1*{PHONE}#','*334*0*{CODE}#',1,true),
  ('UG','Uganda','🇺🇬','+256','UGX','Ugandan Shilling','770 000 000','MTN Uganda','MTN MoMo','*165*1*{PHONE}#','*165*5*{CODE}#',2,true),
  ('TZ','Tanzania','🇹🇿','+255','TZS','Tanzanian Shilling','700 000 000','Vodacom Tanzania','M-Pesa','*150*00*1*{PHONE}#','*150*00*5*{CODE}#',3,true),
  ('RW','Rwanda','🇷🇼','+250','RWF','Rwandan Franc','788 767 816','MTN Rwanda','MTN MoMo','*182*1*1*{PHONE}#','*182*8*1*{CODE}#',4,true),
  ('ET','Ethiopia','🇪🇹','+251','ETB','Ethiopian Birr','910 000 000','Ethio Telecom','Telebirr','*127*1*{PHONE}#','*127*3*{CODE}#',5,true),
  ('GH','Ghana','🇬🇭','+233','GHS','Ghanaian Cedi','240 000 000','MTN Ghana','MTN MoMo','*170*1*{PHONE}#','*170*2*{CODE}#',6,true),
  ('NG','Nigeria','🇳🇬','+234','NGN','Nigerian Naira','703 000 000','MTN Nigeria','MoMo PSB','*671*1*{PHONE}#','*671*5*{CODE}#',7,true),
  ('SN','Senegal','🇸🇳','+221','XOF','West African CFA Franc','770 000 000','Orange Senegal','Orange Money','*144*1*{PHONE}#','*144*5*{CODE}#',8,true),
  ('CI','Côte d''Ivoire','🇨🇮','+225','XOF','West African CFA Franc','070 000 000','MTN CI','MTN MoMo','*133*1*{PHONE}#','*133*5*{CODE}#',9,true),
  ('BJ','Benin','🇧🇯','+229','XOF','West African CFA Franc','970 000 000','MTN Benin','MTN MoMo','*400*1*{PHONE}#','*400*8*{CODE}#',10,true),
  ('GN','Guinea','🇬🇳','+224','GNF','Guinean Franc','620 000 000','Orange Guinea','Orange Money','*501*1*{PHONE}#','*501*4*{CODE}#',11,true),
  ('GW','Guinea-Bissau','🇬🇼','+245','XOF','West African CFA Franc','900 000 000','MTN Guinea-Bissau','MTN MoMo','*124*1*{PHONE}#','*124*8*{CODE}#',12,true),
  ('LR','Liberia','🇱🇷','+231','LRD','Liberian Dollar','770 000 000','Orange Liberia','Orange Money','*144*1*{PHONE}#','*144*4*{CODE}#',13,true),
  ('SL','Sierra Leone','🇸🇱','+232','SLE','Sierra Leonean Leone','760 000 00','Orange Sierra Leone','Orange Money','*144*1*{PHONE}#','*144*5*{CODE}#',14,true),
  ('CD','DR Congo','🇨🇩','+243','CDF','Congolese Franc','820 000 000','Vodacom DRC','M-Pesa','*135*1*{PHONE}#','*135*5*{CODE}#',15,true),
  ('CM','Cameroon','🇨🇲','+237','XAF','Central African CFA Franc','60 000 000','MTN Cameroon','MTN MoMo','*126*1*{PHONE}#','*126*7*2*{CODE}#',16,true),
  ('CG','Congo Brazzaville','🇨🇬','+242','XAF','Central African CFA Franc','60 000 000','MTN Congo','MTN MoMo','*150*1*{PHONE}#','*150*8*{CODE}#',17,true),
  ('GA','Gabon','🇬🇦','+241','XAF','Central African CFA Franc','70 000 000','Airtel Gabon','Airtel Money','*150*1*{PHONE}#','*150*6*{CODE}#',18,true),
  ('ZA','South Africa','🇿🇦','+27','ZAR','South African Rand','830 000 000','MTN South Africa','MTN MoMo','*120*668*1*{PHONE}#','*120*668*4*{CODE}#',19,true),
  ('ZM','Zambia','🇿🇲','+260','ZMW','Zambian Kwacha','960 000 000','MTN Zambia','MTN MoMo','*303*1*{PHONE}#','*303*4*{CODE}#',20,true),
  ('ZW','Zimbabwe','🇿🇼','+263','ZWG','Zimbabwe Gold (ZiG)','770 000 000','Econet Wireless','EcoCash','*151*1*{PHONE}#','*151*3*{CODE}#',21,true),
  ('MW','Malawi','🇲🇼','+265','MWK','Malawian Kwacha','990 000 000','Airtel Malawi','Airtel Money','*311*1*{PHONE}#','*311*6*{CODE}#',22,true),
  ('MZ','Mozambique','🇲🇿','+258','MZN','Mozambican Metical','840 000 000','Vodacom MZ','M-Pesa','*150*1*{PHONE}#','*150*5*{CODE}#',23,true),
  ('SZ','Eswatini','🇸🇿','+268','SZL','Swazi Lilangeni','760 000 000','MTN Eswatini','MTN MoMo','*166*1*{PHONE}#','*166*4*{CODE}#',24,true),
  ('BW','Botswana','🇧🇼','+267','BWP','Botswana Pula','700 000 00','Mascom Wireless','MyZaka','*167*1*{PHONE}#','*167*4*{CODE}#',25,true),
  ('MG','Madagascar','🇲🇬','+261','MGA','Malagasy Ariary','340 000 000','Airtel Madagascar','Airtel Money','*150*1*{PHONE}#','*150*6*{CODE}#',26,true),
  ('US','USA','🇺🇸','+1','USD','US Dollar','555 000 0000','','','','',90,true),
  ('GB','UK','🇬🇧','+44','GBP','British Pound','7700 000000','','','','',91,true)
ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, flag=EXCLUDED.flag, dialing_code=EXCLUDED.dialing_code,
  currency=EXCLUDED.currency, currency_name=EXCLUDED.currency_name,
  phone_placeholder=EXCLUDED.phone_placeholder, telecom_provider=EXCLUDED.telecom_provider,
  momo_brand=EXCLUDED.momo_brand, ussd_number_format=EXCLUDED.ussd_number_format,
  ussd_code_format=EXCLUDED.ussd_code_format, sort_order=EXCLUDED.sort_order;
