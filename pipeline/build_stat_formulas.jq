# build_stat_formulas.jq
# Input: stats.json  { "data.game.stats": [...] }
# Args:
#   --argjson ui        stat_ui_config.json contents
#   --arg     version   ISO date string (e.g. "2025-06-16")
#
# Output: stat_formulas.json — browser-ready formula bundle for the SPA engine

.data.game.stats as $src |

# ── Lookups ────────────────────────────────────────────────────────────────────
($src | map({key: .id, value: .}) | from_entries) as $byId |

# Primary stats: player-allocated, not computed (statType == "Primary")
[$src[] | select(.statType == "Primary") | .id] | sort as $primaries |

# Gear-injectable inputs: have op "0" but accept equipment bonuses.
# Listed explicitly since statType doesn't distinguish them.
["BonusHealth", "BonusGutsValue", "BonusGutsThreshold", "BonusEvasionChance", "BaseBlockValue"] as $gear |

# ── Formula cleaning ───────────────────────────────────────────────────────────
# Converts C# expression strings into valid JavaScript expressions.
def clean_expr:
  # Resolve Ctx.GetOrCalculateStat(Stat.X) -> stats.X
  gsub("Ctx\\.GetOrCalculateStat\\(Stat\\.(?<X>\\w*)\\)"; "stats.\(.X)")
  # Strip C# (float) casts — no-op in JS
  | gsub("\\(float\\)\\s*"; "")
  # Strip f/F suffix from numeric literals: 0.015f -> 0.015, 1f -> 1
  | gsub("(?<n>[0-9]+\\.?[0-9]*)f\\b"; "\(.n)")
  # Map C# static Math methods to JS equivalents
  | gsub("System\\.Math\\.Exp"; "Math.exp")
  | gsub("System\\.Math\\.Pow"; "Math.pow")
  | gsub("System\\.Math\\.Abs"; "Math.abs")
  | gsub("System\\.Math\\.Sqrt"; "Math.sqrt")
  # Trim surrounding whitespace
  | ltrimstr(" ") | rtrimstr(" ")
;

# Extract all stats.X references as a unique sorted array of X values
def extract_deps:
  [match("stats\\.(?<n>\\w+)"; "g") | .captures[0].string]
  | unique
  | sort
;

# ── Build formula table ────────────────────────────────────────────────────────
# Include all stats that:
#   - are not primary (those are inputs)
#   - are not gear-injectable zero-constants (also inputs)
#   - have a non-empty operation string
(
  $src
  | map(select(
      (.id as $id | ($primaries | index($id)) == null)
      and (.id as $id | ($gear    | index($id)) == null)
      and ((.operation // "") | length > 0)
    ))
  | map({
      key: .id,
      value: {
        name: .name,
        expr: (.operation | clean_expr),
        deps: (.operation | clean_expr | extract_deps)
      }
    })
  | sort_by(.key)
  | from_entries
) as $formulas |

# ── Synthetic (editorial) formulas ──────────────────────────────────────────
# Formulas not present in the API (e.g. derived combat readouts). Authored in
# stat_ui_config.json; evaluated by the same engine. API formulas stay
# authoritative on any id collision ($synthetic listed first).
(
    ($ui.synthetic // {}) | to_entries | map({
    key: .key,
    value: {
        name: .value.name,
        expr: (.value.expr | clean_expr),
        deps: (.value.expr | clean_expr | extract_deps)
    }
    }) | from_entries
) as $synthetic |
($synthetic + $formulas) as $formulas |

# ── Validation ─────────────────────────────────────────────────────────────────
# Every dep referenced in a formula must be resolvable: either a primary stat,
# a gear input, or another formula entry.  Unknown refs are surfaced as errors.
(($primaries + $gear) + ($formulas | keys)) as $all_known |

(
  $formulas | to_entries | map(
    .key as $stat |
    .value.deps[] |
    . as $dep |
    if ($all_known | index($dep)) == null
    then "ERROR: formula '\($stat)' references unknown stat '\($dep)'"
    else empty
    end
  )
) as $errors |

# Emit errors to stderr and abort if any found
if ($errors | length) > 0
then
  ($errors[] | stderr) |
  error("Validation failed: unresolvable stat references found")
else . end |

# ── Assemble output ────────────────────────────────────────────────────────────
{
  version:  $version,
  primary:  $primaries,
  gear:     $gear,
  baseValue: 5,
  formulas: $formulas,
  ui: ($ui | del(.synthetic))
}
