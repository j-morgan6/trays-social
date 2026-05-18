// ios-screens.jsx — All 10 iOS screens for Trays. Dark, iPhone 15 Pro.

// ─────────────────────────────────────────────────────────────
// 1. Sign-in / Onboarding (welcome screen — 3 trays explained)
// ─────────────────────────────────────────────────────────────
function IOSSignin() {
  return (
    <div data-screen-label="iOS · Welcome">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          {/* Hero photo, top quarter */}
          <Photo variant="tomato" style={{ height: 340, width: '100%' }} />

          {/* Wordmark + title in the dark area */}
          <div style={{ padding: '32px 24px 0', flex: 1, display: 'flex', flexDirection: 'column' }}>
            <div className="serif" style={{ fontSize: 22, color: T.secondary, marginBottom: 18 }}>Trays</div>

            <h1 className="serif" style={{
              fontSize: 38, fontWeight: 400, lineHeight: 1.05, margin: '0 0 12px',
              color: T.dText, letterSpacing: '-0.015em',
            }}>
              Three trays.<br/>One quiet place<br/>to cook from.
            </h1>

            <p style={{ fontSize: 14, color: T.dMuted, lineHeight: 1.55, margin: '0 0 26px' }}>
              You've got an account. Here's how Trays works.
            </p>

            {/* Three trays */}
            {[
              { icon: <IconHome size={18}/>, t: 'Feed', d: 'Recipes from the cooks you follow, plus a few suggestions.' },
              { icon: <IconSearch size={18}/>, t: 'Find', d: '"I\'m hungry — find me food." Filter chips do the work.' },
              { icon: <IconBookmark size={18}/>, t: 'My Tray', d: 'Everything you\'ve saved, in collections you name.' },
            ].map((x, i) => (
              <div key={x.t} style={{
                display: 'flex', alignItems: 'flex-start', gap: 14,
                padding: '12px 0',
                borderBottom: i < 2 ? `1px solid ${T.dHair}` : '0',
              }}>
                <div style={{
                  width: 38, height: 38, borderRadius: 8,
                  background: 'rgba(165,214,167,0.16)',
                  color: T.secondary,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  flexShrink: 0,
                }}>{x.icon}</div>
                <div>
                  <div className="serif" style={{ fontSize: 19, color: T.dText, lineHeight: 1.1 }}>{x.t}</div>
                  <div style={{ fontSize: 12, color: T.dMuted, marginTop: 3, lineHeight: 1.5 }}>{x.d}</div>
                </div>
              </div>
            ))}

            <div style={{ flex: 1 }} />

            <button className="btn amber" style={{ width: '100%', height: 52, fontSize: 15, marginBottom: 14 }}>
              Take me to my Feed
            </button>
          </div>

          {/* Home indicator spacing handled by IOSDevice */}
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 2. Feed
// ─────────────────────────────────────────────────────────────
function IOSFeed() {
  return (
    <div data-screen-label="iOS · Feed">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          <IOSHeaderDark
            title="Feed"
            eyebrow="THU · MAY 15"
            trailing={
              <div style={{ position: 'relative', color: T.dMuted }}>
                <IconBell size={20}/>
                <div style={{ position: 'absolute', top: -2, right: -2, width: 7, height: 7, borderRadius: '50%', background: T.accent }} />
              </div>
            }
          />

          <div style={{ flex: 1, overflow: 'auto', padding: '6px 16px 110px' }}>
            <IOSRecipeCard
              photo="tomato" title="Sunday short ribs over polenta"
              cook="Mara Chen" avatarPalette="warm" time="2h"
              teaser="Bone-in beef short ribs, red wine, thyme. The fond is the whole thing — don't rush it. Cooked this for my dad's birthday and he had thirds."
              likes={24} saves={86} comments={6}
            />

            {/* Discovery insert — clearly labeled */}
            <div style={{
              padding: '12px 14px', marginBottom: 14,
              background: 'rgba(165,214,167,0.1)',
              border: `1px solid rgba(165,214,167,0.3)`,
              borderRadius: 8,
              display: 'flex', alignItems: 'center', gap: 10,
            }}>
              <IconSearch size={14} style={{ color: T.secondary }} />
              <div style={{ flex: 1 }}>
                <div className="mono" style={{ fontSize: 9, color: T.secondary, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
                  From Find · adjacent to your saves
                </div>
                <div style={{ fontSize: 12, color: T.dText, marginTop: 2 }}>
                  Two suggestions interleaved — never an ad.
                </div>
              </div>
            </div>

            <IOSRecipeCard
              photo="greens" title="Charred broccolini, anchovy butter"
              cook="Devi Rao" avatarPalette="sage" time="Yesterday"
              teaser="Single sheet pan. Skip the anchovy if you don't have it — flaky salt and lemon, equally good."
              likes={18} saves={42} comments={3}
              isDiscovery
            />

            <IOSRecipeCard
              photo="lemon" title="Cardamom morning bun, lazy"
              cook="Theo Park" avatarPalette="amber" time="Tue"
              teaser="Yes, lazy. No yeast. Brown butter, cardamom, an honest croissant dough from the freezer."
              likes={31} saves={64} comments={4}
            />
          </div>

          <IOSTabBar active="feed" />
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 3. Search / Find
// ─────────────────────────────────────────────────────────────
function IOSFind() {
  const chips = [
    { l: 'Under 30 min', icon: <IconClock size={11}/>, on: true },
    { l: 'Vegetarian', icon: <IconLeaf size={11}/>, on: false },
    { l: 'One pan', icon: <IconPan size={11}/>, on: true },
    { l: 'Has video', on: false },
    { l: 'By cooks I follow', icon: <IconUser size={11}/>, on: false },
  ];
  return (
    <div data-screen-label="iOS · Find">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          <div style={{ paddingTop: 56, paddingLeft: 20, paddingRight: 20, paddingBottom: 4 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
              <div className="serif" style={{ fontSize: 20, color: T.secondary }}>Trays</div>
              <div style={{ flex: 1 }} />
              <div style={{ color: T.dMuted }}><IconSliders size={20}/></div>
            </div>

            {/* Search */}
            <div style={{
              height: 44, background: T.dSurface, borderRadius: 22,
              display: 'flex', alignItems: 'center', gap: 10, padding: '0 16px',
              color: T.dMuted, fontSize: 14,
            }}>
              <IconSearch size={16}/>
              <span style={{ color: T.dText }}>chickpeas, lemon</span>
              <span style={{ display: 'inline-block', width: 1.5, height: 16, background: T.secondary, animation: 'blink 1s steps(2) infinite' }} />
              <span style={{ flex: 1 }} />
              <span className="mono" style={{ fontSize: 10, letterSpacing: '0.1em' }}>14</span>
            </div>
          </div>

          {/* Chip strip */}
          <div style={{
            display: 'flex', gap: 6, padding: '12px 20px 16px', overflow: 'auto',
          }}>
            {chips.map(c => (
              <span key={c.l} className={'chip dark ' + (c.on ? 'active' : '')}
                style={{ height: 32, fontSize: 12, flexShrink: 0 }}>
                {c.icon}{c.l}
              </span>
            ))}
          </div>

          <div style={{ flex: 1, overflow: 'auto', padding: '0 20px 110px' }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 14 }}>
              <h2 className="serif" style={{ fontSize: 22, fontWeight: 400, color: T.dText, margin: 0 }}>
                14 recipes
              </h2>
              <div className="mono" style={{ fontSize: 9, color: T.dMuted, letterSpacing: '0.12em', textTransform: 'uppercase' }}>
                Sorted: time ↑
              </div>
            </div>

            {/* Hero result */}
            <div style={{ background: T.dSurface, borderRadius: 10, overflow: 'hidden', marginBottom: 14, border: '1px solid ' + T.dHair }}>
              <Photo variant="greens" style={{ height: 200 }} />
              <div style={{ padding: '14px 16px' }}>
                <h3 className="serif" style={{ fontSize: 20, fontWeight: 400, lineHeight: 1.1, color: T.dText, margin: '0 0 6px' }}>
                  Charred broccolini, anchovy butter
                </h3>
                <div style={{ fontSize: 11, color: T.dMuted, lineHeight: 1.5 }}>
                  Devi Rao · 22 min · one pan
                </div>
                <div style={{ fontSize: 11, color: T.secondary, marginTop: 6 }}>
                  You have 5 of 6 ingredients. Missing: anchovy paste.
                </div>
              </div>
            </div>

            {/* Result rows */}
            {[
              { p: 'lemon', t: 'Skillet citrus chickpeas', c: 'Lior · 18 min · pantry' },
              { p: 'cream', t: 'Tinned-fish toast', c: 'Yuna · 9 min · 5 ingredients' },
              { p: 'greens', t: 'Big-leaf herb salad', c: 'Mara · 11 min' },
            ].map((r, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '80px 1fr', gap: 14,
                padding: '12px 0', borderBottom: '1px solid ' + T.dHair,
              }}>
                <Photo variant={r.p} style={{ height: 80, borderRadius: 6 }} />
                <div>
                  <h4 className="serif" style={{ fontSize: 17, fontWeight: 400, color: T.dText, margin: '0 0 4px', lineHeight: 1.15 }}>{r.t}</h4>
                  <div style={{ fontSize: 11, color: T.dMuted }}>{r.c}</div>
                </div>
              </div>
            ))}
          </div>

          <IOSTabBar active="find" />
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 4. Recipe Detail
// ─────────────────────────────────────────────────────────────
function IOSRecipe() {
  return (
    <div data-screen-label="iOS · Recipe detail">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, overflow: 'auto' }}>
          {/* Photo + overlaid controls + title */}
          <div style={{ position: 'relative' }}>
            <Photo variant="tomato" style={{ height: 360 }} />
            <div style={{
              position: 'absolute', inset: 0,
              background: 'linear-gradient(180deg, rgba(0,0,0,0.4) 0%, rgba(0,0,0,0) 30%, rgba(0,0,0,0) 60%, rgba(0,0,0,0.85) 100%)',
            }} />
            <div style={{
              position: 'absolute', top: 56, left: 16, right: 16, zIndex: 10,
              display: 'flex', justifyContent: 'space-between',
            }}>
              <div style={{ width: 38, height: 38, borderRadius: 19, background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(12px)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <IconChevL size={18}/>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <div style={{ width: 38, height: 38, borderRadius: 19, background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(12px)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <IconShare size={16}/>
                </div>
                <div style={{ width: 38, height: 38, borderRadius: 19, background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(12px)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <IconBookmark size={16}/>
                </div>
              </div>
            </div>
            <div style={{ position: 'absolute', bottom: 18, left: 20, right: 20, zIndex: 10 }}>
              <div className="mono" style={{ fontSize: 10, color: T.secondary, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
                Mains · Beef · Slow
              </div>
              <h1 className="serif" style={{
                fontSize: 32, fontWeight: 400, lineHeight: 1, color: '#fff', margin: '6px 0 0',
                letterSpacing: '-0.015em',
              }}>
                Sunday short ribs<br/>over polenta
              </h1>
            </div>
          </div>

          {/* Cook byline */}
          <div style={{
            padding: '14px 20px', display: 'flex', alignItems: 'center', gap: 12,
            borderBottom: '1px solid ' + T.dHair,
          }}>
            <Avatar initial="M" size={36} palette="warm" />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, color: T.dText, fontWeight: 600 }}>Mara Chen</div>
              <div style={{ fontSize: 11, color: T.dMuted }}>84 recipes · 428 followers</div>
            </div>
            <button style={{
              height: 32, padding: '0 14px', borderRadius: 16,
              background: T.primaryDk, color: '#fff', border: 0, fontSize: 12, fontWeight: 600,
            }}>Follow</button>
          </div>

          {/* Metadata row */}
          <div style={{
            display: 'flex', justifyContent: 'space-between', padding: '14px 20px',
            borderBottom: '1px solid ' + T.dHair,
          }}>
            {[
              { l: 'Total', v: '3h 20m' },
              { l: 'Active', v: '35m' },
              { l: 'Serves', v: '4' },
              { l: 'Tools', v: '4' },
            ].map(m => (
              <div key={m.l}>
                <div className="mono" style={{ fontSize: 9, color: T.dMuted, letterSpacing: '0.12em', textTransform: 'uppercase' }}>{m.l}</div>
                <div className="serif" style={{ fontSize: 18, color: T.dText, marginTop: 3 }}>{m.v}</div>
              </div>
            ))}
          </div>

          {/* Cook's note */}
          <p style={{
            padding: '18px 20px', margin: 0, fontSize: 15, color: T.dText, lineHeight: 1.55,
            fontFamily: 'var(--serif)', fontStyle: 'italic',
            borderBottom: '1px solid ' + T.dHair,
          }}>
            "Cooked this for my dad's birthday. He had thirds. The trick is reducing the wine three minutes longer than feels right."
          </p>

          {/* Method — large step, optimized for arm's length */}
          <div style={{ padding: '20px' }}>
            <div className="mono" style={{ fontSize: 10, color: T.secondary, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
              Step 2 of 4 · swipe to advance
            </div>
            <h2 className="serif" style={{ fontSize: 28, color: T.dText, fontWeight: 400, margin: '6px 0 12px', lineHeight: 1.1 }}>
              Build the base.
            </h2>
            <p style={{ fontSize: 17, lineHeight: 1.55, color: T.dText, margin: 0 }}>
              Pour off all but a tablespoon of fat. Add onion cut-side down, carrots, garlic; cook until darkly colored,
              <b style={{ color: T.accent }}> 6–8 min</b>. Tomato paste, stir, 1 min until brick-red.
            </p>

            {/* Per-step timer */}
            <div style={{
              marginTop: 16, padding: 14, background: T.dSurface, borderRadius: 10,
              border: '1px solid ' + T.dHair,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{
                width: 52, height: 52, borderRadius: '50%',
                border: `2px solid ${T.accent}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: 'var(--serif)', fontSize: 18, color: T.accent,
              }}>6:00</div>
              <div style={{ flex: 1 }}>
                <div className="mono" style={{ fontSize: 9, color: T.dMuted, letterSpacing: '0.12em', textTransform: 'uppercase' }}>
                  Step timer
                </div>
                <div style={{ fontSize: 14, color: T.dText, marginTop: 2 }}>Tap when onions look right.</div>
              </div>
              <button style={{
                height: 34, padding: '0 14px', borderRadius: 17, border: 0,
                background: T.accent, color: '#2a1c00', fontSize: 12, fontWeight: 600,
              }}>Start</button>
            </div>
          </div>

          {/* Engagement row — quiet */}
          <div style={{
            padding: '16px 20px', borderTop: '1px solid ' + T.dHair,
            display: 'flex', gap: 22, alignItems: 'center',
            color: T.dMuted, fontSize: 12,
          }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}><IconHeart size={14}/> 24</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}><IconComment size={14}/> 6 notes</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}><IconCookpot size={14}/> 18</span>
          </div>

          <div style={{ height: 80 }} />
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 5. Create Recipe — step 3 of 5 (Ingredients)
// ─────────────────────────────────────────────────────────────
function IOSCreate() {
  const stepsList = ['Photo', 'Title', 'Ingredients', 'Tools', 'Method'];
  const active = 2;
  return (
    <div data-screen-label="iOS · Create recipe">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          {/* Header */}
          <div style={{ paddingTop: 56, paddingLeft: 16, paddingRight: 16, paddingBottom: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
              <div style={{ color: T.dMuted }}><IconClose size={20}/></div>
              <div style={{ flex: 1 }} />
              <span className="mono" style={{ fontSize: 10, color: T.dMuted, letterSpacing: '0.14em' }}>
                AUTOSAVED
              </span>
            </div>
            {/* Thin progress strip */}
            <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
              {stepsList.map((s, i) => (
                <div key={s} style={{
                  flex: 1, height: 3, borderRadius: 1.5,
                  background: i <= active ? T.primaryDk : T.dHair,
                }} />
              ))}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }}>
              <span className="mono" style={{ fontSize: 9, color: T.dMuted, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
                Step 3 of 5
              </span>
              <span className="mono" style={{ fontSize: 9, color: T.secondary, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
                Ingredients
              </span>
            </div>
          </div>

          <div style={{ flex: 1, overflow: 'auto', padding: '14px 20px 110px' }}>
            <h1 className="serif" style={{
              fontSize: 32, fontWeight: 400, color: T.dText, lineHeight: 1.05,
              margin: '0 0 8px', letterSpacing: '-0.015em',
            }}>What's in it?</h1>
            <p style={{ fontSize: 13, color: T.dMuted, lineHeight: 1.55, margin: '0 0 20px' }}>
              One ingredient per line.
            </p>

            <div style={{ background: T.dSurface, borderRadius: 10, overflow: 'hidden' }}>
              {[
                { q: '4 lb', n: 'bone-in beef short ribs', note: 'patted very dry' },
                { q: '2 tbsp', n: 'neutral oil', note: '' },
                { q: '1', n: 'large yellow onion, halved', note: '' },
                { q: '6', n: 'garlic cloves, smashed', note: '' },
                { q: '1 cup', n: 'dry red wine', note: 'something you\'d drink' },
                { q: '', n: '', note: '', placeholder: true },
              ].map((r, i) => (
                <div key={i} style={{
                  display: 'grid', gridTemplateColumns: '70px 1fr', gap: 10,
                  padding: '12px 16px', borderBottom: '1px solid ' + T.dHair, alignItems: 'flex-start',
                  opacity: r.placeholder ? 0.5 : 1,
                }}>
                  <div className="mono" style={{ fontSize: 13, color: r.placeholder ? T.dMuted : T.secondary }}>
                    {r.q || 'qty'}
                  </div>
                  <div>
                    <div style={{ fontSize: 14, color: r.placeholder ? T.dMuted : T.dText }}>
                      {r.n || 'ingredient…'}
                    </div>
                    {r.note && (
                      <div style={{ fontSize: 12, fontStyle: 'italic', color: T.dMuted, fontFamily: 'var(--serif)', marginTop: 2 }}>
                        {r.note}
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>

            {/* Smart suggestions */}
            <div style={{ marginTop: 14, padding: 14, background: 'rgba(165,214,167,0.08)', borderRadius: 10, border: `1px solid rgba(165,214,167,0.2)` }}>
              <div className="mono" style={{ fontSize: 9, color: T.secondary, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
                Suggested next
              </div>
              <div style={{ display: 'flex', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
                {['tomato paste', 'beef stock', 'thyme', 'bay leaves'].map(s => (
                  <span key={s} className="chip dark" style={{ height: 28, fontSize: 11 }}>
                    <IconPlus size={10}/> {s}
                  </span>
                ))}
              </div>
            </div>

            {/* Preview hint */}
            <div style={{ marginTop: 14, fontSize: 11, color: T.dMuted, fontStyle: 'italic', fontFamily: 'var(--serif)', textAlign: 'center' }}>
              Swipe right to preview the recipe card.
            </div>
          </div>

          {/* Bottom continue */}
          <div style={{
            position: 'absolute', bottom: 36, left: 16, right: 16, zIndex: 30,
            display: 'flex', gap: 10,
          }}>
            <button style={{
              width: 52, height: 52, borderRadius: 26, border: 0,
              background: T.dSurface, color: T.dText,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}><IconArrowL size={18}/></button>
            <button className="btn amber" style={{ flex: 1, height: 52, fontSize: 14 }}>
              Continue to tools <IconArrowR size={14}/>
            </button>
          </div>
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 6. Profile
// ─────────────────────────────────────────────────────────────
function IOSProfile() {
  return (
    <div data-screen-label="iOS · Profile">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          {/* Header strip */}
          <div style={{ paddingTop: 56, paddingLeft: 16, paddingRight: 16, paddingBottom: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ color: T.dMuted }}><IconChevL size={20}/></div>
            <div style={{ flex: 1 }} />
            <div style={{ color: T.dMuted }}><IconShare size={18}/></div>
          </div>

          <div style={{ flex: 1, overflow: 'auto', padding: '0 20px 110px' }}>
            {/* Hero */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 18 }}>
              <Avatar initial="M" size={80} palette="warm" />
              <div>
                <h1 className="serif" style={{ fontSize: 30, fontWeight: 400, lineHeight: 1, color: T.dText, margin: '0 0 4px', letterSpacing: '-0.015em' }}>
                  Mara Chen
                </h1>
                <div style={{ fontSize: 12, color: T.dMuted }}>@mara.cooks · Brooklyn</div>
              </div>
            </div>

            <p style={{ fontSize: 14, color: T.dText, lineHeight: 1.5, margin: '0 0 16px' }}>
              Daughter of a butcher, sister to a baker. Mostly braises, slow eggs, stone fruit.
            </p>

            {/* Counts row */}
            <div style={{ display: 'flex', gap: 24, marginBottom: 16, color: T.dMuted, fontSize: 12, alignItems: 'baseline' }}>
              <span><b style={{ color: T.dText, fontFamily: 'var(--serif)', fontSize: 18 }}>84</b> recipes</span>
              <span><b style={{ color: T.dText, fontFamily: 'var(--serif)', fontSize: 18 }}>428</b> followers</span>
              <span><b style={{ color: T.dText, fontFamily: 'var(--serif)', fontSize: 18 }}>52</b> following</span>
            </div>

            {/* Follow button */}
            <button className="btn" style={{ width: '100%', height: 42, background: T.primaryDk, fontSize: 14, marginBottom: 20 }}>
              Follow Mara
            </button>

            {/* Tabs */}
            <div style={{
              display: 'flex', gap: 22, borderBottom: '1px solid ' + T.dHair, marginBottom: 16,
            }}>
              {[
                { id: 'recipes', label: 'Recipes', count: 84, active: true },
                { id: 'about', label: 'About', count: null },
              ].map(t => (
                <div key={t.id} style={{
                  padding: '10px 0', cursor: 'pointer',
                  borderBottom: t.active ? `2px solid ${T.secondary}` : '2px solid transparent',
                  color: t.active ? T.dText : T.dMuted,
                  fontWeight: t.active ? 600 : 500, fontSize: 13,
                }}>
                  {t.label}
                  {t.count !== null && <span style={{ marginLeft: 6, color: T.dMuted, fontWeight: 500 }}>{t.count}</span>}
                </div>
              ))}
            </div>

            {/* Grid 3-up */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
              {[
                { p: 'tomato', t: 'Short ribs', m: '3h 20' },
                { p: 'greens', t: 'Broccolini', m: '22 min' },
                { p: 'lemon', t: 'Morning bun', m: '1h 10' },
                { p: 'cream', t: 'Cacio e pepe', m: '45 min' },
                { p: 'dark', t: 'Honey chicken', m: '50 min' },
                { p: 'blueb', t: 'Galette', m: '1h 40' },
                { p: 'tomato', t: 'Bucatini', m: '40 min' },
                { p: 'greens', t: 'Herb salad', m: '11 min' },
                { p: 'cream', t: 'Toast', m: '9 min' },
              ].map((r, i) => (
                <div key={i} style={{ position: 'relative', borderRadius: 4, overflow: 'hidden' }}>
                  <Photo variant={r.p} style={{ height: 116 }} />
                  <div style={{
                    position: 'absolute', bottom: 0, left: 0, right: 0,
                    padding: '14px 8px 6px',
                    background: 'linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.8) 100%)',
                    color: '#fff',
                  }}>
                    <div className="serif" style={{ fontSize: 12, lineHeight: 1.1 }}>{r.t}</div>
                    <div className="mono" style={{ fontSize: 8, letterSpacing: '0.08em', opacity: 0.85, marginTop: 2 }}>{r.m}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <IOSTabBar active="profile" />
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 7. My Tray
// ─────────────────────────────────────────────────────────────
function IOSMyTray() {
  return (
    <div data-screen-label="iOS · My Tray (saved)">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          <IOSHeaderDark title="My Tray" eyebrow="38 SAVED · 5 COLLECTIONS" />

          {/* Collection chips row */}
          <div style={{ padding: '0 0 14px' }}>
            <div style={{ display: 'flex', gap: 8, padding: '0 20px', overflow: 'auto' }}>
              {[
                { n: 'All saved', c: 38, p: 'tomato', active: true },
                { n: 'To try', c: 14, p: 'lemon' },
                { n: 'Mainstays', c: 9, p: 'cream' },
                { n: 'Weeknight', c: 12, p: 'greens' },
                { n: 'Sunday', c: 6, p: 'dark' },
                { n: 'Mom\'s', c: 7, p: 'blueb', priv: true },
              ].map(c => (
                <div key={c.n} style={{
                  flexShrink: 0, width: 124,
                  borderRadius: 8, overflow: 'hidden',
                  border: c.active ? `1.5px solid ${T.secondary}` : '1px solid ' + T.dHair,
                  background: T.dSurface,
                }}>
                  <Photo variant={c.p} style={{ height: 72 }} />
                  <div style={{ padding: '8px 10px' }}>
                    <div className="serif" style={{ fontSize: 13, color: T.dText, lineHeight: 1.1 }}>{c.n}</div>
                    <div className="mono" style={{ fontSize: 8, color: T.dMuted, letterSpacing: '0.12em', textTransform: 'uppercase', marginTop: 3 }}>
                      {c.c} recipes{c.priv && ' · private'}
                    </div>
                  </div>
                </div>
              ))}
              <div style={{
                flexShrink: 0, width: 124, height: 122,
                border: `1px dashed ${T.dBorder}`, borderRadius: 8,
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                gap: 6, color: T.dMuted,
              }}>
                <IconPlus size={16}/>
                <span style={{ fontSize: 11, fontFamily: 'var(--serif)', fontStyle: 'italic' }}>New collection</span>
              </div>
            </div>
          </div>

          <div style={{ flex: 1, overflow: 'auto', padding: '0 20px 110px' }}>
            {[
              { p: 'tomato', t: 'Sunday short ribs over polenta', c: 'Mara Chen', col: 'Mainstays · cooked 2×', m: '3h 20m · 11 ingredients' },
              { p: 'greens', t: 'Charred broccolini, anchovy butter', c: 'Devi Rao', col: 'Weeknight', m: '22 min · 6 ingredients' },
              { p: 'lemon', t: 'Cardamom morning bun', c: 'Theo Park', col: 'To try', m: '1h 10m · 9 ingredients' },
              { p: 'cream', t: 'Pici cacio e pepe', c: 'Yuna Aoki', col: 'Mainstays', m: '45 min · 5 ingredients' },
            ].map((r, i) => (
              <div key={i} style={{
                background: T.dSurface, borderRadius: 10, overflow: 'hidden',
                marginBottom: 12, border: '1px solid ' + T.dHair,
                display: 'grid', gridTemplateColumns: '110px 1fr',
              }}>
                <Photo variant={r.p} style={{ height: 110 }} />
                <div style={{ padding: '12px 14px' }}>
                  <div style={{ fontSize: 11, color: T.dMuted, marginBottom: 3 }}>{r.c}</div>
                  <h4 className="serif" style={{ fontSize: 17, fontWeight: 400, color: T.dText, lineHeight: 1.1, margin: '0 0 4px' }}>{r.t}</h4>
                  <div style={{ fontSize: 11, color: T.dMuted, marginBottom: 6 }}>{r.m}</div>
                  <div className="mono" style={{
                    display: 'inline-block', fontSize: 8, color: T.secondary,
                    letterSpacing: '0.14em', textTransform: 'uppercase',
                    padding: '3px 7px', background: 'rgba(165,214,167,0.16)', borderRadius: 99,
                  }}>{r.col}</div>
                </div>
              </div>
            ))}
          </div>

          <IOSTabBar active="mytray" />
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 8. Comments — bottom sheet over recipe
// ─────────────────────────────────────────────────────────────
function IOSComments() {
  const comments = [
    { who: 'Devi Rao', u: '@devi.rao', p: 'sage', when: '2h', body: "Did this with chuck — shaved 30 min off the braise. The cold-butter polenta tip is the move." },
    { who: 'Mara Chen', u: '@mara.cooks', p: 'warm', when: '1h', body: 'Yes! Chuck works well when it\'s marbled.', isCook: true, isReply: true },
    { who: 'Theo Park', u: '@theo', p: 'amber', when: 'Yest.', body: 'Subbed half the wine for tawny port. Heretical. Excellent.' },
    { who: 'Yuna Aoki', u: '@yuna.20min', p: 'plum', when: '2d', body: 'Made a half batch in the same pot. Came out the same.' },
    { who: 'Lior Bavli', u: '@lior', p: 'sky', when: '3d', body: 'How long can these sit in the braising liquid? Asking for Sunday prep.' },
  ];
  return (
    <div data-screen-label="iOS · Comments (bottom sheet)">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
          {/* Recipe background, blurred */}
          <Photo variant="tomato" style={{ position: 'absolute', inset: 0, height: '100%', filter: 'brightness(0.45)' }} />

          {/* Sheet */}
          <div style={{
            marginTop: 'auto', position: 'relative', zIndex: 5,
            background: T.dSurface,
            borderRadius: '24px 24px 0 0',
            display: 'flex', flexDirection: 'column',
            height: '78%',
            boxShadow: '0 -10px 30px rgba(0,0,0,0.4)',
          }}>
            {/* Handle */}
            <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 10 }}>
              <div style={{ width: 36, height: 4, borderRadius: 2, background: 'rgba(255,255,255,0.25)' }} />
            </div>

            {/* Header */}
            <div style={{
              padding: '12px 20px 14px', borderBottom: '1px solid ' + T.dHair,
              display: 'flex', alignItems: 'baseline', gap: 8,
            }}>
              <h2 className="serif" style={{ fontSize: 22, fontWeight: 400, margin: 0, color: T.dText }}>Cook's notes</h2>
              <span style={{ fontSize: 11, color: T.dMuted }}>· 6 notes</span>
              <div style={{ flex: 1 }} />
              <div style={{ color: T.dMuted }}><IconClose size={18}/></div>
            </div>

            {/* Comments */}
            <div style={{ flex: 1, overflow: 'auto', padding: '8px 20px 0' }}>
              {comments.map((c, i) => (
                <div key={i} style={{
                  display: 'grid', gridTemplateColumns: c.isReply ? '24px 28px 1fr' : '32px 1fr',
                  gap: 10, padding: '14px 0',
                  borderBottom: i < comments.length - 1 ? '1px solid ' + T.dHair : '0',
                }}>
                  {c.isReply && <div style={{ alignSelf: 'stretch', width: 2, marginLeft: 12, background: T.dHair }}/>}
                  <Avatar initial={c.who[0]} size={c.isReply ? 28 : 32} palette={c.p}/>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, flexWrap: 'wrap' }}>
                      <span style={{ fontSize: 13, color: T.dText, fontWeight: 600 }}>{c.who}</span>
                      {c.isCook && (
                        <span style={{
                          background: T.secondary, color: '#0f2611',
                          padding: '1px 6px', borderRadius: 99,
                          fontSize: 9, fontWeight: 600,
                        }}>Cook</span>
                      )}
                      <span className="mono" style={{ fontSize: 9, color: T.dMuted, letterSpacing: '0.06em', marginLeft: 'auto' }}>{c.when}</span>
                    </div>
                    <p style={{ fontSize: 13, color: T.dText, lineHeight: 1.55, margin: '4px 0 4px' }}>{c.body}</p>
                    <button style={{ background: 'transparent', border: 0, color: T.dMuted, fontSize: 11, fontFamily: 'inherit', padding: 0 }}>
                      Reply
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {/* Composer */}
            <div style={{
              padding: '12px 16px 24px', borderTop: '1px solid ' + T.dHair,
              display: 'flex', gap: 8, alignItems: 'center', background: T.dBg,
            }}>
              <Avatar initial="E" size={32} />
              <div style={{
                flex: 1, height: 38, background: T.dSurface, borderRadius: 19,
                padding: '0 14px',
                display: 'flex', alignItems: 'center',
                fontSize: 13, color: T.dMuted, fontStyle: 'italic', fontFamily: 'var(--serif)',
              }}>
                Cooked it? Leave a note…
              </div>
              <button style={{
                width: 38, height: 38, borderRadius: 19, border: 0,
                background: T.primaryDk, color: '#fff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <IconSend size={15}/>
              </button>
            </div>
          </div>
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 9. Followers
// ─────────────────────────────────────────────────────────────
function IOSFollowers() {
  const cooks = [
    { n: 'Devi Rao', u: '@devi.rao', p: 'sage', bio: 'Brooklyn · veg-leaning, one pan', following: true },
    { n: 'Theo Park', u: '@theo', p: 'amber', bio: 'Oakland · pantry-first', following: true },
    { n: 'Yuna Aoki', u: '@yuna.20min', p: 'plum', bio: 'Portland · 20-min lunches', following: true },
    { n: 'Lior Bavli', u: '@lior', p: 'sky', bio: 'Tel Aviv · chickpeas, citrus', following: false },
    { n: 'Jules Aman', u: '@jules.bakes', p: 'warm', bio: 'Montréal · galettes', following: false },
    { n: 'Soo Park', u: '@sooooo', p: 'sage', bio: 'Brooklyn · crispy edges', following: true },
    { n: 'Anya Reyes', u: '@anya.new', p: 'amber', bio: 'New to Trays · braises', following: false, newCook: true },
    { n: 'Ben Cohen', u: '@bencooks', p: 'plum', bio: 'New to Trays · smoked', following: false, newCook: true },
  ];
  return (
    <div data-screen-label="iOS · Followers">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          {/* Header */}
          <div style={{ paddingTop: 56, paddingLeft: 16, paddingRight: 16, paddingBottom: 8, display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ color: T.dMuted }}><IconChevL size={20}/></div>
            <div className="serif" style={{ fontSize: 17, color: T.dText }}>Mara Chen</div>
            <div style={{ flex: 1 }} />
          </div>

          {/* Tabs */}
          <div style={{ display: 'flex', gap: 22, padding: '0 20px', borderBottom: '1px solid ' + T.dHair, marginBottom: 10 }}>
            {[
              { label: 'Followers', count: 428, active: true },
              { label: 'Following', count: 52 },
            ].map(t => (
              <div key={t.label} style={{
                padding: '10px 0', cursor: 'pointer',
                borderBottom: t.active ? `2px solid ${T.secondary}` : '2px solid transparent',
                fontFamily: 'var(--serif)', fontSize: 18, color: t.active ? T.dText : T.dMuted,
              }}>
                {t.label}<span style={{ marginLeft: 6, fontSize: 13, color: T.dMuted, fontFamily: 'var(--ui)' }}>{t.count}</span>
              </div>
            ))}
          </div>

          {/* Search field */}
          <div style={{ padding: '10px 20px 14px' }}>
            <div style={{
              height: 38, background: T.dSurface, borderRadius: 19,
              display: 'flex', alignItems: 'center', gap: 10, padding: '0 14px',
              color: T.dMuted, fontSize: 13,
            }}>
              <IconSearch size={14}/>
              <span>Search 428 followers</span>
            </div>
          </div>

          {/* List */}
          <div style={{ flex: 1, overflow: 'auto', padding: '0 20px 110px' }}>
            {cooks.map((c, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '40px 1fr auto', gap: 12,
                padding: '12px 0', alignItems: 'center',
                borderBottom: i < cooks.length - 1 ? '1px solid ' + T.dHair : '0',
              }}>
                <Avatar initial={c.n[0]} size={40} palette={c.p}/>
                <div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, flexWrap: 'wrap' }}>
                    <span style={{ fontSize: 14, color: T.dText, fontWeight: 600 }}>{c.n}</span>
                    {c.newCook && (
                      <span style={{
                        background: 'rgba(165,214,167,0.2)', color: T.secondary,
                        padding: '1px 6px', borderRadius: 99,
                        fontSize: 9, fontFamily: 'var(--mono)', letterSpacing: '0.1em', textTransform: 'uppercase',
                      }}>New</span>
                    )}
                  </div>
                  <div style={{ fontSize: 11, color: T.dMuted, marginTop: 2 }}>{c.u}</div>
                  <div style={{ fontSize: 11, color: T.dMuted, marginTop: 2, lineHeight: 1.4 }}>{c.bio}</div>
                </div>
                {c.following ? (
                  <button style={{ height: 30, padding: '0 12px', borderRadius: 15, background: 'transparent', color: T.dText, border: `1px solid ${T.dBorder}`, fontSize: 11 }}>Following</button>
                ) : (
                  <button style={{ height: 30, padding: '0 12px', borderRadius: 15, background: T.primaryDk, color: '#fff', border: 0, fontSize: 11, fontWeight: 600 }}>Follow</button>
                )}
              </div>
            ))}
          </div>
        </div>
      </IOSDevice>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 10. Notifications
// ─────────────────────────────────────────────────────────────
function IOSNotifications() {
  const items = [
    { kind: 'save', who: 'Maria Quintero', extra: 'and 3 others', p: 'sage', when: '12m', recipe: 'Sunday short ribs', photo: 'tomato', unread: true },
    { kind: 'comment', who: 'Devi Rao', p: 'sage', when: '1h', recipe: 'Sunday short ribs', photo: 'tomato', body: 'Did this with chuck. Worked beautifully…', unread: true },
    { kind: 'follow', who: 'Lior Bavli', p: 'sky', when: '3h', bio: 'Tel Aviv · chickpeas, citrus' },
    { kind: 'like', who: 'Theo Park', extra: 'and 12 others', p: 'amber', when: '5h', recipe: 'Broccolini', photo: 'greens' },
    { kind: 'cooked', who: 'Yuna Aoki', p: 'plum', when: 'Yest.', recipe: 'Cacio e pepe', photo: 'cream', body: '"Made it Tuesday. The lemon hits."' },
    { kind: 'save', who: 'Soo Park', extra: 'and 8 others', p: 'sage', when: '2d', recipe: 'Honey chicken', photo: 'dark' },
    { kind: 'follow', who: 'Anya Reyes', p: 'amber', when: '3d', bio: 'New to Trays · braises' },
  ];
  const phrase = (it) => {
    switch (it.kind) {
      case 'save': return <><b>{it.who}</b>{it.extra && <> {it.extra}</>} saved your <em>{it.recipe}</em></>;
      case 'comment': return <><b>{it.who}</b> left a note on <em>{it.recipe}</em></>;
      case 'like': return <><b>{it.who}</b>{it.extra && <> {it.extra}</>} found <em>{it.recipe}</em> helpful</>;
      case 'follow': return <><b>{it.who}</b> followed you</>;
      case 'cooked': return <><b>{it.who}</b> cooked your <em>{it.recipe}</em></>;
    }
  };
  return (
    <div data-screen-label="iOS · Notifications">
      <IOSDevice dark width={402} height={874}>
        <div className="screen dark" style={{ height: '100%', background: T.dBg, position: 'relative', display: 'flex', flexDirection: 'column' }}>
          <IOSHeaderDark title="Notes for you" eyebrow="7 TODAY · 2 UNREAD" />

          <div style={{ flex: 1, overflow: 'auto', padding: '8px 0 110px' }}>
            {items.map((it, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '40px 1fr 64px', gap: 12,
                padding: '14px 20px',
                background: it.unread ? 'rgba(255,179,0,0.05)' : 'transparent',
                borderBottom: '1px solid ' + T.dHair,
                position: 'relative',
              }}>
                <Avatar initial={it.who[0]} size={40} palette={it.p}/>
                <div>
                  <div style={{
                    fontSize: 14, color: T.dText, lineHeight: 1.4,
                    fontFamily: 'var(--serif)',
                  }}>
                    {phrase(it)}
                  </div>
                  {it.body && (
                    <div style={{ fontSize: 12, color: T.dMuted, marginTop: 4, fontStyle: 'italic', fontFamily: 'var(--serif)' }}>
                      {it.body}
                    </div>
                  )}
                  {it.bio && <div style={{ fontSize: 11, color: T.dMuted, marginTop: 4 }}>{it.bio}</div>}
                  <div className="mono" style={{ fontSize: 9, color: T.dMuted, letterSpacing: '0.12em', marginTop: 6 }}>
                    {it.when}
                  </div>
                </div>
                {it.photo ? (
                  <Photo variant={it.photo} style={{ width: 64, height: 64, borderRadius: 4 }} />
                ) : it.kind === 'follow' ? (
                  <button style={{ height: 30, padding: '0 10px', borderRadius: 15, background: T.primaryDk, color: '#fff', border: 0, fontSize: 11, fontWeight: 600, alignSelf: 'center' }}>
                    Follow back
                  </button>
                ) : <div/>}
                {it.unread && (
                  <div style={{
                    position: 'absolute', left: 8, top: '50%', transform: 'translateY(-50%)',
                    width: 6, height: 6, borderRadius: '50%', background: T.accent,
                  }} />
                )}
              </div>
            ))}
            <div style={{ padding: '20px', textAlign: 'center', fontSize: 11, color: T.dMuted, fontStyle: 'italic', fontFamily: 'var(--serif)' }}>
              Quiet by design.
            </div>
          </div>
        </div>
      </IOSDevice>
    </div>
  );
}

Object.assign(window, {
  IOSSignin, IOSFeed, IOSFind, IOSRecipe, IOSCreate,
  IOSProfile, IOSMyTray, IOSComments, IOSFollowers, IOSNotifications,
});
