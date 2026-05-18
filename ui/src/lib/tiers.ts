export type TierValue =
  | "mfs"
  | "gf-audit"
  | "gf-advisory"
  | "gf-tax"
  | "g9-us"
  | "g9-ca"
  | "g9-uk"
  | "g9-de"
  | "g9-fr"
  | "g9-nl"
  | "g9-au"
  | "g9-jp"
  | "g9-cn";

export type Hub = "amr" | "emea" | "apac";

export interface TierDef {
  value: TierValue;
  label: string;
  group: "MFS" | "Global Function" | "G9 Member Firms";
  flag?: string;
}

export const TIERS: TierDef[] = [
  { value: "mfs",         label: "MFS Shared",        group: "MFS" },
  { value: "gf-audit",    label: "GF Audit",          group: "Global Function" },
  { value: "gf-advisory", label: "GF Advisory",       group: "Global Function" },
  { value: "gf-tax",      label: "GF Tax",            group: "Global Function" },
  { value: "g9-us",       label: "G9 United States",  group: "G9 Member Firms", flag: "🇺🇸" },
  { value: "g9-ca",       label: "G9 Canada",         group: "G9 Member Firms", flag: "🇨🇦" },
  { value: "g9-uk",       label: "G9 United Kingdom", group: "G9 Member Firms", flag: "🇬🇧" },
  { value: "g9-de",       label: "G9 Germany",        group: "G9 Member Firms", flag: "🇩🇪" },
  { value: "g9-fr",       label: "G9 France",         group: "G9 Member Firms", flag: "🇫🇷" },
  { value: "g9-nl",       label: "G9 Netherlands",    group: "G9 Member Firms", flag: "🇳🇱" },
  { value: "g9-au",       label: "G9 Australia",      group: "G9 Member Firms", flag: "🇦🇺" },
  { value: "g9-jp",       label: "G9 Japan",          group: "G9 Member Firms", flag: "🇯🇵" },
  { value: "g9-cn",       label: "G9 China",          group: "G9 Member Firms", flag: "🇨🇳" },
];

export const TIER_GROUPS = ["MFS", "Global Function", "G9 Member Firms"] as const;

export const FOUNDRY_RGS = [
  ...TIERS.map((t) => ({
    tier: t.value,
    label: t.label,
    rg: (hub: Hub) => `rg-agentops-${t.value}-${hub}`,
    foundry: (hub: Hub) => `foundry-${t.value}-${hub}`,
  })),
  {
    tier: "shared",
    label: "Shared (APIM Gateway)",
    rg: (hub: Hub) => `rg-agentops-shared-${hub}`,
    foundry: (hub: Hub) => `apim-foundry-${hub}`,
  },
] as const;
