/*
  # Standardize stock_dispo column names to lowercase
  
  Problem: Inconsistent column naming between table definition (uppercase) and usage (lowercase)
  Solution: Rename all columns to lowercase for consistency with PostgreSQL conventions
  
  This ensures all references to stock_dispo columns work consistently across the application.
*/

-- Rename columns to lowercase for consistency
ALTER TABLE stock_dispo RENAME COLUMN "qté_GDC" TO qté_gdc;
ALTER TABLE stock_dispo RENAME COLUMN "qté_JDC" TO qté_jdc;
ALTER TABLE stock_dispo RENAME COLUMN "qté_CAT_Network" TO qté_cat_network;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_10" TO qté_succ_10;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_11" TO qté_succ_11;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_12" TO qté_succ_12;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_13" TO qté_succ_13;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_14" TO qté_succ_14;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_19" TO qté_succ_19;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_20" TO qté_succ_20;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_21" TO qté_succ_21;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_22" TO qté_succ_22;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_24" TO qté_succ_24;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_30" TO qté_succ_30;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_40" TO qté_succ_40;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_50" TO qté_succ_50;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_60" TO qté_succ_60;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_70" TO qté_succ_70;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_80" TO qté_succ_80;
ALTER TABLE stock_dispo RENAME COLUMN "qté_SUCC_90" TO qté_succ_90;
