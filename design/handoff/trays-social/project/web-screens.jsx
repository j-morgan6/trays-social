// web-screens.jsx — All 10 web screens for Trays, 1280 design width.

// ─────────────────────────────────────────────────────────────
// 1. Sign-in / Onboarding (landing + sign-up form)
// ─────────────────────────────────────────────────────────────
function WebSignin() {
  return (
    <div className="screen" data-screen-label="Web · Sign-in & onboarding"
      style={{ background: T.bg, height: '100%' }}>
      <header style={{
        height: 72, display: 'flex', alignItems: 'center', padding: '0 48px',
        justifyContent: 'space-between',
      }}>
        <div className="serif" style={{ fontSize: 30, color: T.primary }}>Trays</div>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <span style={{ fontSize: 13, color: T.muted }}>Already cooking on Trays?</span>
          <button className="btn ghost" style={{ height: 36, fontSize: 13 }}>Sign in</button>
        </div>
      </header>

      <main style={{ padding: '24px 48px 48px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 56, alignItems: 'start' }}>
        {/* Hero pitch */}
        <div style={{ paddingTop: 40 }}>
          <div className="mono" style={{
            fontSize: 11, color: T.primary, letterSpacing: '0.18em',
            textTransform: 'uppercase', marginBottom: 28,
          }}>For home cooks · Est. 2026</div>
          <h1 className="serif" style={{
            fontSize: 84, lineHeight: 0.95, fontWeight: 400, margin: '0 0 24px',
            color: T.text, letterSpacing: '-0.015em',
          }}>
            What did<br/>you cook<br/><em style={{ color: T.primary }}>tonight?</em>
          </h1>
          <p style={{ fontSize: 18, color: T.muted, lineHeight: 1.55, maxWidth: 440, margin: 0 }}>
            Trays is for home cooks documenting what they actually make — ingredients,
            tools, timing, method. Written down well, by people you'd want to eat with.
          </p>

          {/* The three trays preview */}
          <div style={{ marginTop: 40, display: 'flex', gap: 16 }}>
            {[
              { p: 'tomato', t: 'Feed' },
              { p: 'greens', t: 'Find' },
              { p: 'lemon', t: 'My Tray' },
            ].map(x => (
              <div key={x.t} style={{ flex: 1 }}>
                <Photo variant={x.p} style={{ height: 90, borderRadius: 4 }} />
                <div className="serif" style={{ fontSize: 16, marginTop: 8, color: T.text }}>{x.t}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Sign-up form */}
        <div style={{
          background: T.surface, borderRadius: 8, padding: 32,
          border: `1px solid ${T.border}`,
          boxShadow: '0 2px 18px rgba(20,40,20,0.04)',
          maxWidth: 480, marginLeft: 'auto', marginTop: 20,
        }}>
          <h2 className="serif" style={{ fontSize: 32, fontWeight: 400, margin: '0 0 6px', lineHeight: 1.1 }}>
            Start your tray
          </h2>
          <p style={{ fontSize: 13, color: T.muted, margin: '0 0 24px', lineHeight: 1.5 }}>
            Takes thirty seconds. Email, a username people can find you by, a password.
          </p>

          {/* Email */}
          <Field label="Email" value="ezra.m@kitchen.com" />

          {/* Username with live validation */}
          <div style={{ marginBottom: 16 }}>
            <Field label="Username" value="ezra.makes" valid={true} validNote="Available · 11 of 30 chars" />
          </div>

          {/* Password */}
          <Field label="Password" value="••••••••••" type="password" />

          <div style={{
            margin: '8px 0 20px', fontSize: 12, color: T.muted, lineHeight: 1.5,
          }}>
            By signing up you agree to the <span style={{ color: T.primary, fontWeight: 600 }}>house rules</span> — be useful, be a person, be kind to cooks.
          </div>

          <button className="btn" style={{ width: '100%', background: T.primary, height: 48 }}>
            Make me a tray
          </button>

          <div style={{
            marginTop: 24, paddingTop: 16, borderTop: `1px solid ${T.hair}`,
            fontSize: 12, color: T.muted, textAlign: 'center',
          }}>
            No social login. No email confirmation. You'll be cooking in under a minute.
          </div>
        </div>
      </main>
    </div>
  );
}

function Field({ label, value, type = 'text', valid, validNote }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <label style={{ fontSize: 12, color: T.muted, fontWeight: 600, display: 'block', marginBottom: 6 }}>{label}</label>
      <div style={{
        position: 'relative', height: 44, borderRadius: 8,
        border: `1px solid ${valid ? T.primary : T.border}`,
        background: T.bg, display: 'flex', alignItems: 'center', padding: '0 14px',
      }}>
        <span style={{ fontSize: 14, color: T.text }}>{value}</span>
        {valid && (
          <div style={{ marginLeft: 'auto', color: T.primary }}>
            <IconCheck size={16} stroke={2.4}/>
          </div>
        )}
      </div>
      {validNote && <div style={{ fontSize: 11, color: T.primary, marginTop: 4 }}>{validNote}</div>}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 2. Feed
// ─────────────────────────────────────────────────────────────
function WebFeed() {
  const posts = [
    {
      photo: 'tomato', title: 'Sunday short ribs over polenta',
      cook: 'Mara Chen', avatarPalette: 'warm', time: '2h',
      ingredients: { time: '3 hr 20 min', count: 11, tools: 4, teaser: 'Bone-in beef short ribs, red wine, thyme, soft polenta finished with cold butter. The fond is the whole thing — don\'t rush it.' },
      tags: ['Slow', 'Sunday', 'Beef'],
      likes: 24, saves: 86, comments: 6, saved: true,
    },
    {
      photo: 'greens', title: 'Charred broccolini, anchovy butter',
      cook: 'Devi Rao', avatarPalette: 'sage', time: 'Yesterday',
      ingredients: { time: '22 min', count: 6, tools: 2, teaser: 'Single sheet pan. Skip the anchovy if you don\'t have it — flaky salt and lemon, equally good. Eat directly from the pan, ideally.' },
      tags: ['Under 30 min', 'Vegetarian'],
      likes: 18, saves: 42, comments: 3,
    },
  ];
  return (
    <div className="screen" data-screen-label="Web · Feed"
      style={{ background: T.bg, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <WebHeader active="feed" />

      <main style={{
        flex: 1, overflow: 'auto', padding: '32px 48px 48px',
        display: 'grid', gridTemplateColumns: '1fr 320px', gap: 40, maxWidth: 1280, margin: '0 auto', width: '100%',
      }}>
        {/* Feed column */}
        <div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginBottom: 24 }}>
            <h1 className="serif" style={{ fontSize: 40, fontWeight: 400, margin: 0, letterSpacing: '-0.015em' }}>
              This week
            </h1>
            <div className="mono" style={{ fontSize: 11, color: T.muted, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
              Thu · May 15
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <RecipeCard {...posts[0]} />

            {/* Discovery insert — clearly labeled */}
            <div style={{
              padding: '14px 18px',
              background: 'rgba(165,214,167,0.18)',
              border: `1px solid ${T.secondary}`,
              borderRadius: 4,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{ width: 28, height: 28, borderRadius: '50%', background: T.secondary, display: 'flex', alignItems: 'center', justifyContent: 'center', color: T.primary }}>
                <IconSearch size={14}/>
              </div>
              <div style={{ flex: 1 }}>
                <div className="mono" style={{ fontSize: 10, color: T.primary, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
                  From Find · because you like one-pan dinners
                </div>
                <div style={{ fontSize: 13, color: T.text, marginTop: 2 }}>
                  Two suggestions interleaved — not a paid placement, just adjacent recipes.
                </div>
              </div>
            </div>

            <RecipeCard {...posts[1]} />
          </div>
        </div>

        {/* Right rail — quiet metadata */}
        <aside style={{ paddingTop: 14 }}>
          <div style={{
            background: T.surface, borderRadius: 4, padding: 20,
            border: `1px solid ${T.hair}`,
          }}>
            <div className="mono" style={{ fontSize: 10, color: T.muted, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
              Following
            </div>
            <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[
                { n: 'Mara Chen', u: '@mara.cooks', p: 'warm', new: true },
                { n: 'Devi Rao', u: '@devi.rao', p: 'sage', new: true },
                { n: 'Theo Park', u: '@theo', p: 'amber' },
                { n: 'Yuna Aoki', u: '@yuna.20min', p: 'plum' },
              ].map(c => (
                <div key={c.u} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <Avatar initial={c.n[0]} size={32} palette={c.p}/>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, color: T.text }}>{c.n}</div>
                    <div style={{ fontSize: 11, color: T.muted }}>{c.u}</div>
                  </div>
                  {c.new && <div style={{ width: 8, height: 8, borderRadius: '50%', background: T.primary }}/>}
                </div>
              ))}
            </div>
            <div style={{ marginTop: 14, fontSize: 12, color: T.primary, fontWeight: 600 }}>
              See all 12 →
            </div>
          </div>

          <div style={{
            background: T.surface, borderRadius: 4, padding: 20, marginTop: 16,
            border: `1px solid ${T.hair}`,
          }}>
            <div className="mono" style={{ fontSize: 10, color: T.muted, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
              In season this week
            </div>
            <div style={{ marginTop: 8, fontFamily: 'var(--serif)', fontSize: 16, lineHeight: 1.5, color: T.text }}>
              Garlic scapes. <span style={{ color: T.muted }}>Strawberries finally good. Snap peas. The first of the corn.</span>
            </div>
          </div>
        </aside>
      </main>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 3. Search / Find
// ─────────────────────────────────────────────────────────────
function WebFind() {
  const chips = [
    { l: 'Under 30 min', icon: <IconClock size={11}/>, on: true },
    { l: 'Vegetarian', icon: <IconLeaf size={11}/>, on: false },
    { l: 'One pan', icon: <IconPan size={11}/>, on: true },
    { l: 'Has video', on: false },
    { l: 'By cooks I follow', icon: <IconUser size={11}/>, on: false },
  ];
  return (
    <div className="screen" data-screen-label="Web · Find"
      style={{ background: T.bg, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <WebHeader active="find" />

      {/* Sticky search + filter bar */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 5,
        background: T.surface, borderBottom: `1px solid ${T.hair}`,
        padding: '24px 48px 16px',
      }}>
        <div style={{ maxWidth: 1280, margin: '0 auto' }}>
          <div style={{
            height: 56, borderRadius: 28, background: T.bg, border: `1px solid ${T.border}`,
            display: 'flex', alignItems: 'center', padding: '0 22px', gap: 14, marginBottom: 14,
          }}>
            <IconSearch size={18} style={{ color: T.muted }}/>
            <span style={{ fontSize: 17, color: T.text }}>chickpeas, lemon</span>
            <span style={{ display: 'inline-block', width: 2, height: 22, background: T.primary, animation: 'blink 1s steps(2) infinite' }} />
            <div style={{ flex: 1 }} />
            <span className="mono" style={{ fontSize: 11, color: T.muted, letterSpacing: '0.1em' }}>
              14 MATCHES
            </span>
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {chips.map(c => (
              <span key={c.l} className={'chip ' + (c.on ? 'active' : '')} style={{ height: 32, fontSize: 13 }}>
                {c.icon}{c.l}
                {c.on && <IconClose size={11} style={{ marginLeft: 4, opacity: 0.7 }}/>}
              </span>
            ))}
          </div>
        </div>
      </div>

      <main style={{ flex: 1, overflow: 'auto', padding: '32px 48px 48px', maxWidth: 1280, margin: '0 auto', width: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, marginBottom: 20 }}>
          <h2 className="serif" style={{ fontSize: 28, fontWeight: 400, margin: 0 }}>14 recipes for you</h2>
          <div style={{ fontSize: 12, color: T.muted }}>Sorted by time · matching 2 chips</div>
        </div>

        {/* Result grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 24 }}>
          {[
            { p: 'greens', t: 'Charred broccolini, anchovy butter', m: 'Devi · 22 min · one pan', who: 'D' },
            { p: 'lemon', t: 'Skillet citrus chickpeas', m: 'Lior · 18 min · pantry-friendly', who: 'L' },
            { p: 'cream', t: 'Tinned-fish toast', m: 'Yuna · 9 min · 5 ingredients', who: 'Y' },
            { p: 'greens', t: 'Big-leaf herb salad', m: 'Mara · 11 min · raw', who: 'M' },
            { p: 'cream', t: 'Soft scramble on toast', m: 'Theo · 7 min · one pan', who: 'T' },
            { p: 'lemon', t: 'Smashed chickpea salad', m: 'Soo · 10 min · one bowl', who: 'S' },
          ].map((r, i) => (
            <article key={i} style={{
              background: T.surface, borderRadius: 4, overflow: 'hidden',
              border: `1px solid ${T.hair}`,
            }}>
              <Photo variant={r.p} style={{ height: 200 }} />
              <div style={{ padding: 16 }}>
                <h4 className="serif" style={{ fontSize: 20, fontWeight: 400, lineHeight: 1.1, margin: '0 0 6px' }}>
                  {r.t}
                </h4>
                <div style={{ fontSize: 12, color: T.muted }}>{r.m}</div>
                <div style={{
                  display: 'flex', alignItems: 'center', gap: 12, marginTop: 12, paddingTop: 12,
                  borderTop: `1px solid ${T.hair}`, color: T.muted, fontSize: 11,
                }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}><IconHeart size={11}/> {18 - i*2}</span>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}><IconBookmark size={11}/> {42 - i*4}</span>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}><IconComment size={11}/> {5 - i % 3}</span>
                </div>
              </div>
            </article>
          ))}
        </div>
      </main>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 4. Recipe Detail
// ─────────────────────────────────────────────────────────────
function WebRecipe() {
  const ingredients = [
    { qty: '4 lb', name: 'bone-in beef short ribs', note: 'patted very dry' },
    { qty: '2 tbsp', name: 'neutral oil' },
    { qty: '1', name: 'large yellow onion, halved' },
    { qty: '6', name: 'garlic cloves, smashed' },
    { qty: '2', name: 'carrots, big chunks' },
    { qty: '1 cup', name: 'dry red wine', note: "something you'd drink" },
    { qty: '2 cups', name: 'unsalted beef stock' },
    { qty: '2 tbsp', name: 'tomato paste' },
    { qty: '4 sprigs', name: 'thyme' },
    { qty: '2', name: 'bay leaves' },
    { qty: 'flaky salt', name: 'to finish' },
  ];
  const steps = [
    { time: '20 min', title: 'Sear hard, sear patiently',
      body: 'Season the ribs heavily. In a heavy dutch oven, sear in batches over medium-high until a true mahogany crust forms — about 4 min per side. Don\'t crowd. The fond is the whole thing.' },
    { time: '8 min', title: 'Build the base',
      body: 'Pour off all but a tablespoon of fat. Add onion cut-side down, carrots, garlic; cook until darkly colored, 6–8 min. Tomato paste, stir, cook 1 min until brick-red.' },
    { time: '5 min', title: 'Deglaze with the wine',
      body: 'Pour in the wine. Scrape every speck of fond. Reduce by half. Add stock, herbs, ribs back in. Liquid should come three-quarters up.' },
    { time: '2 hr 45', title: 'Braise low and slow',
      body: "Cover, 300°F oven, 2 hr 45 min. Don't open. They're done when a fork slides in with no resistance." },
  ];
  return (
    <div className="screen" data-screen-label="Web · Recipe detail"
      style={{ background: T.bg, height: '100%' }}>
      <WebHeader active="feed" showSearch={false} />

      {/* Hero photo */}
      <Photo variant="tomato" style={{ height: 480 }} />

      <main style={{ maxWidth: 1100, margin: '0 auto', padding: '40px 48px 64px' }}>
        {/* Title + byline */}
        <div className="mono" style={{ fontSize: 11, color: T.primary, letterSpacing: '0.18em', textTransform: 'uppercase' }}>
          Mains · Beef · Slow
        </div>
        <h1 className="serif" style={{
          fontSize: 64, fontWeight: 400, lineHeight: 0.98, margin: '12px 0 16px',
          letterSpacing: '-0.015em',
        }}>
          Sunday short ribs<br/>over polenta
        </h1>

        <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 28 }}>
          <Avatar initial="M" size={44} palette="warm"/>
          <div>
            <div style={{ fontSize: 15, fontWeight: 600 }}>Mara Chen</div>
            <div style={{ fontSize: 12, color: T.muted }}>Brooklyn · 84 recipes on her tray · 428 followers</div>
          </div>
          <button className="btn" style={{ height: 36, fontSize: 13, background: T.primary, padding: '0 16px' }}>Follow</button>
        </div>

        {/* Metadata row */}
        <div style={{
          display: 'flex', gap: 32, padding: '20px 0',
          borderTop: `1px solid ${T.hair}`, borderBottom: `1px solid ${T.hair}`,
          marginBottom: 36, fontSize: 13,
        }}>
          {[
            { l: 'Total time', v: '3 hr 20 min' },
            { l: 'Active', v: '35 min' },
            { l: 'Serves', v: '4' },
            { l: 'Ingredients', v: '11' },
            { l: 'Tools', v: 'Dutch oven, tongs, whisk' },
          ].map(m => (
            <div key={m.l}>
              <div className="mono" style={{ fontSize: 10, color: T.muted, letterSpacing: '0.14em', textTransform: 'uppercase' }}>{m.l}</div>
              <div className="serif" style={{ fontSize: 18, color: T.text, marginTop: 4 }}>{m.v}</div>
            </div>
          ))}
        </div>

        {/* Cook's note */}
        <p style={{
          fontSize: 17, color: T.text, lineHeight: 1.65, fontFamily: 'var(--serif)', fontStyle: 'italic',
          maxWidth: 720, marginBottom: 36,
        }}>
          "Cooked this for my dad's birthday. He's a snob about short ribs. He had thirds. The trick is reducing the wine long enough that it stops smelling like wine — three minutes longer than feels right."
        </p>

        {/* Two-column: Ingredients | Method */}
        <div style={{ display: 'grid', gridTemplateColumns: '0.8fr 1fr', gap: 56 }}>
          <section>
            <h2 className="serif" style={{ fontSize: 28, fontWeight: 400, margin: '0 0 16px' }}>Ingredients</h2>
            <div style={{ borderTop: `1px solid ${T.hair}` }}>
              {ingredients.map((i, idx) => (
                <label key={idx} style={{
                  display: 'grid', gridTemplateColumns: '20px 80px 1fr', gap: 12,
                  alignItems: 'baseline', padding: '10px 0',
                  borderBottom: `1px solid ${T.hair}`, cursor: 'pointer',
                }}>
                  <span style={{
                    width: 16, height: 16, borderRadius: 3, border: `1.5px solid ${T.border}`,
                    background: idx < 3 ? T.primary : 'transparent',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff',
                  }}>{idx < 3 && <IconCheck size={11} stroke={2.6}/>}</span>
                  <span className="mono" style={{
                    fontSize: 12, color: T.muted,
                    textDecoration: idx < 3 ? 'line-through' : 'none',
                  }}>{i.qty}</span>
                  <span style={{
                    fontSize: 14, color: T.text, lineHeight: 1.4,
                    textDecoration: idx < 3 ? 'line-through' : 'none',
                    opacity: idx < 3 ? 0.5 : 1,
                  }}>
                    {i.name}
                    {i.note && <em style={{ color: T.muted, fontStyle: 'italic', fontFamily: 'var(--serif)', marginLeft: 6 }}> — {i.note}</em>}
                  </span>
                </label>
              ))}
            </div>
          </section>

          <section>
            <h2 className="serif" style={{ fontSize: 28, fontWeight: 400, margin: '0 0 16px' }}>Method</h2>
            <div>
              {steps.map((s, idx) => (
                <div key={idx} style={{
                  padding: '20px 0', borderBottom: `1px solid ${T.hair}`,
                  display: 'grid', gridTemplateColumns: '36px 1fr 100px', gap: 14,
                }}>
                  <div className="serif" style={{ fontSize: 30, color: T.primary, lineHeight: 1, fontStyle: 'italic' }}>{idx + 1}</div>
                  <div>
                    <div style={{ fontSize: 17, fontWeight: 600, marginBottom: 6 }}>{s.title}</div>
                    <div style={{ fontSize: 15, lineHeight: 1.65, color: T.text }}>{s.body}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <button style={{
                      border: `1px solid ${T.border}`, background: idx === 0 ? T.accent : T.surface,
                      color: idx === 0 ? '#2a1c00' : T.text, fontWeight: idx === 0 ? 600 : 500,
                      borderRadius: 99, fontSize: 12, padding: '6px 14px',
                      display: 'inline-flex', alignItems: 'center', gap: 5, cursor: 'pointer',
                    }}>
                      <IconClock size={12}/> {s.time}
                    </button>
                    {idx === 0 && (
                      <div className="mono" style={{ fontSize: 10, color: T.accent, marginTop: 5, letterSpacing: '0.1em' }}>
                        TIMER · 12:42
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </section>
        </div>

        {/* Engagement row */}
        <div style={{
          marginTop: 48, paddingTop: 24, borderTop: `2px solid ${T.hair}`,
          display: 'flex', alignItems: 'center', gap: 18,
        }}>
          <button style={{ background: 'transparent', border: 0, color: T.muted, display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontFamily: 'inherit', cursor: 'pointer' }}>
            <IconHeart size={16}/> 24 helpful
          </button>
          <button style={{ background: 'transparent', border: 0, color: T.muted, display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontFamily: 'inherit', cursor: 'pointer' }}>
            <IconComment size={16}/> 6 notes
          </button>
          <button style={{ background: 'transparent', border: 0, color: T.muted, display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontFamily: 'inherit', cursor: 'pointer' }}>
            <IconCookpot size={16}/> 18 cooked
          </button>
          <button style={{ background: 'transparent', border: 0, color: T.muted, display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontFamily: 'inherit', cursor: 'pointer' }}>
            <IconShare size={16}/> Share
          </button>
          <div style={{ flex: 1 }} />
          <button className="btn ghost" style={{ height: 36, fontSize: 13 }}>
            <IconBookmark size={13}/> Save to My Tray
          </button>
          <button className="btn" style={{ height: 36, fontSize: 13, background: T.primary, padding: '0 16px' }}>
            <IconWhisk size={13}/> Start cooking
          </button>
        </div>

        {/* Calm collapsed comments hint */}
        <div style={{
          marginTop: 24, padding: 16, background: T.surface, borderRadius: 4,
          border: `1px solid ${T.hair}`, display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <IconComment size={16} style={{ color: T.muted }}/>
          <span style={{ fontSize: 13, color: T.text }}>6 cooks left notes — Devi, Theo, Yuna, and 3 others</span>
          <div style={{ flex: 1 }} />
          <span style={{ fontSize: 12, color: T.primary, fontWeight: 600 }}>Open notes →</span>
        </div>
      </main>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 5. Create Recipe — step 3 of 5 (Ingredients)
// ─────────────────────────────────────────────────────────────
function WebCreate() {
  const stepsList = ['Photo', 'Title & note', 'Ingredients', 'Tools', 'Method'];
  const active = 2;
  return (
    <div className="screen" data-screen-label="Web · Create recipe"
      style={{ background: T.bg, height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Top progress + meta */}
      <header style={{
        height: 64, background: T.surface, borderBottom: `1px solid ${T.hair}`,
        display: 'flex', alignItems: 'center', padding: '0 32px', gap: 24,
      }}>
        <div className="serif" style={{ fontSize: 22, color: T.primary }}>Trays</div>
        <div style={{ flex: 1 }}>
          {/* Progress steps */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, maxWidth: 640, margin: '0 auto' }}>
            {stepsList.map((s, i) => (
              <React.Fragment key={s}>
                <div style={{
                  width: 26, height: 26, borderRadius: '50%',
                  border: `1.5px solid ${i <= active ? T.primary : T.border}`,
                  background: i < active ? T.primary : (i === active ? '#fff' : 'transparent'),
                  color: i < active ? '#fff' : (i === active ? T.primary : T.muted),
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 12, fontFamily: 'var(--mono)', fontWeight: 600,
                }}>
                  {i < active ? <IconCheck size={12} stroke={2.6}/> : (i + 1)}
                </div>
                <span style={{
                  fontSize: 12, color: i === active ? T.text : T.muted,
                  fontWeight: i === active ? 600 : 500,
                  display: i === active ? 'inline' : 'none',
                }}>{s}</span>
                {i < stepsList.length - 1 && (
                  <div style={{ flex: 1, height: 1, background: i < active ? T.primary : T.hair, minWidth: 16 }} />
                )}
              </React.Fragment>
            ))}
          </div>
        </div>
        <span className="mono" style={{ fontSize: 11, color: T.muted, letterSpacing: '0.14em' }}>
          DRAFT · AUTOSAVED
        </span>
        <button className="btn ghost" style={{ height: 32, fontSize: 12 }}>Close</button>
      </header>

      <div style={{ flex: 1, overflow: 'auto', display: 'grid', gridTemplateColumns: '1fr 380px', minHeight: 0 }}>
        {/* Form */}
        <main style={{ padding: '48px 64px', maxWidth: 720, margin: '0 auto', width: '100%' }}>
          <div className="mono" style={{ fontSize: 11, color: T.primary, letterSpacing: '0.18em', textTransform: 'uppercase' }}>
            Step 3 of 5
          </div>
          <h1 className="serif" style={{ fontSize: 52, fontWeight: 400, margin: '8px 0 12px', lineHeight: 1.05 }}>
            What's in it?
          </h1>
          <p style={{ fontSize: 15, color: T.muted, margin: '0 0 36px', lineHeight: 1.55 }}>
            One ingredient per line. Quantity, name, a note if it matters. Press <span className="mono" style={{ background: T.bg, padding: '1px 6px', borderRadius: 3, fontSize: 12 }}>Tab</span> to jump between fields.
          </p>

          <div style={{ background: T.surface, borderRadius: 6, border: `1px solid ${T.hair}`, overflow: 'hidden' }}>
            <div style={{
              display: 'grid', gridTemplateColumns: '110px 1fr 200px 32px', gap: 12,
              padding: '10px 16px', background: T.bg, borderBottom: `1px solid ${T.hair}`,
              fontFamily: 'var(--mono)', fontSize: 10, color: T.muted, letterSpacing: '0.14em', textTransform: 'uppercase',
            }}>
              <span>Qty + unit</span>
              <span>Ingredient</span>
              <span>Note (optional)</span>
              <span />
            </div>
            {[
              { q: '4 lb', n: 'bone-in beef short ribs', note: 'patted very dry' },
              { q: '2 tbsp', n: 'neutral oil', note: '' },
              { q: '1', n: 'large yellow onion, halved', note: '' },
              { q: '6', n: 'garlic cloves, smashed', note: '' },
              { q: '1 cup', n: 'dry red wine', note: 'something you\'d drink' },
              { q: '', n: '', note: '', placeholder: true },
            ].map((r, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '110px 1fr 200px 32px', gap: 12,
                padding: '12px 16px', borderBottom: `1px solid ${T.hair}`, alignItems: 'center',
              }}>
                <div className="mono" style={{ fontSize: 13, color: r.placeholder ? T.muted : T.text, opacity: r.placeholder ? 0.4 : 1 }}>
                  {r.q || 'qty'}
                </div>
                <div style={{ fontSize: 14, color: r.placeholder ? T.muted : T.text, opacity: r.placeholder ? 0.4 : 1 }}>
                  {r.n || 'ingredient…'}
                </div>
                <div style={{
                  fontSize: 13, fontStyle: 'italic', color: T.muted,
                  fontFamily: 'var(--serif)', opacity: r.placeholder ? 0.4 : 1,
                }}>{r.note || (r.placeholder ? '' : '—')}</div>
                <div style={{ color: T.muted, opacity: r.placeholder ? 0 : 1 }}>
                  <IconClose size={14}/>
                </div>
              </div>
            ))}
          </div>

          {/* Smart suggestions */}
          <div style={{ marginTop: 16, padding: 16, background: 'rgba(165,214,167,0.12)', borderRadius: 6, border: `1px solid ${T.secondary}` }}>
            <div className="mono" style={{ fontSize: 10, color: T.primary, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
              Smart unit suggestions
            </div>
            <div style={{ display: 'flex', gap: 6, marginTop: 10, flexWrap: 'wrap' }}>
              {['tomato paste', 'beef stock', 'thyme', 'bay leaves', 'flaky salt'].map(s => (
                <span key={s} className="chip" style={{ height: 28, fontSize: 12, background: '#fff' }}>
                  <IconPlus size={11}/> {s}
                </span>
              ))}
            </div>
          </div>

          {/* Bottom actions */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 32 }}>
            <button className="btn ghost"><IconArrowL size={14}/> Title & note</button>
            <div style={{ flex: 1 }} />
            <button className="btn amber">
              Continue to tools <IconArrowR size={14}/>
            </button>
          </div>
        </main>

        {/* Right rail: live preview */}
        <aside style={{ background: '#1A1611', padding: '32px 28px', borderLeft: `1px solid ${T.hair}` }}>
          <div className="mono" style={{ fontSize: 10, color: 'rgba(255,255,255,0.6)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>
            Live preview
          </div>
          <div style={{
            marginTop: 14, background: T.surface, borderRadius: 4, overflow: 'hidden',
            boxShadow: '0 12px 30px rgba(0,0,0,0.3)',
          }}>
            <Photo variant="tomato" style={{ height: 180 }} />
            <div style={{ padding: 16 }}>
              <h4 className="serif" style={{ fontSize: 22, fontWeight: 400, lineHeight: 1.05, margin: '0 0 6px' }}>
                Sunday short ribs over polenta
              </h4>
              <div style={{ fontSize: 12, color: T.muted, marginBottom: 10 }}>
                By Ezra · 5 ingredients so far
              </div>
              <div style={{ fontSize: 12, color: T.muted, lineHeight: 1.5, fontFamily: 'var(--serif)', fontStyle: 'italic' }}>
                "Cooked this for my dad's birthday. The trick is reducing the wine until it stops smelling like wine."
              </div>
            </div>
          </div>
          <div style={{ marginTop: 14, fontSize: 11, color: 'rgba(255,255,255,0.5)', lineHeight: 1.55 }}>
            This is how your recipe card will look in Feed and Find. It updates as you write.
          </div>
        </aside>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 6. Profile
// ─────────────────────────────────────────────────────────────
function WebProfile() {
  return (
    <div className="screen" data-screen-label="Web · Profile"
      style={{ background: T.bg, height: '100%' }}>
      <WebHeader />

      <main style={{ maxWidth: 1180, margin: '0 auto', padding: '40px 48px 48px' }}>
        {/* Hero */}
        <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr auto', gap: 28, alignItems: 'center', marginBottom: 8 }}>
          <Avatar initial="M" size={120} palette="warm" />
          <div>
            <h1 className="serif" style={{ fontSize: 52, fontWeight: 400, margin: '0 0 4px', lineHeight: 1, letterSpacing: '-0.015em' }}>
              Mara Chen
            </h1>
            <div style={{ fontSize: 14, color: T.muted, marginBottom: 12 }}>
              @mara.cooks <span style={{ margin: '0 8px' }}>·</span> Brooklyn, NY
            </div>
            <p style={{ fontSize: 15, color: T.text, maxWidth: 560, margin: 0, lineHeight: 1.55 }}>
              Daughter of a butcher, sister to a baker. Mostly braises, slow eggs, stone fruit.
              Cooking is the only thing I do where rushing always hurts the outcome.
            </p>
            <div style={{ marginTop: 14, display: 'flex', gap: 22, fontSize: 13, color: T.muted, alignItems: 'baseline' }}>
              <span><b style={{ color: T.text, fontFamily: 'var(--serif)', fontSize: 18 }}>84</b> recipes</span>
              <span style={{ cursor: 'pointer' }}><b style={{ color: T.text, fontFamily: 'var(--serif)', fontSize: 18 }}>428</b> followers</span>
              <span style={{ cursor: 'pointer' }}><b style={{ color: T.text, fontFamily: 'var(--serif)', fontSize: 18 }}>52</b> following</span>
              <span><b style={{ color: T.text, fontFamily: 'var(--serif)', fontSize: 18 }}>312</b> cooks this year</span>
            </div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, alignSelf: 'start' }}>
            <button className="btn" style={{ background: T.primary, height: 40, fontSize: 14 }}>
              Follow Mara
            </button>
            <button className="btn ghost" style={{ height: 40, fontSize: 14 }}>Message</button>
          </div>
        </div>

        {/* Tabs */}
        <div style={{
          display: 'flex', gap: 28, marginTop: 36, borderBottom: `1px solid ${T.hair}`,
        }}>
          {[
            { id: 'recipes', label: 'Recipes', count: 84, active: true },
            { id: 'saved', label: 'Saved', count: null, hint: 'visible only on your own profile' },
            { id: 'about', label: 'About', count: null },
          ].map(t => (
            <div key={t.id} style={{
              padding: '12px 0', cursor: 'pointer',
              borderBottom: t.active ? `2px solid ${T.primary}` : '2px solid transparent',
              color: t.active ? T.text : T.muted,
              fontWeight: t.active ? 600 : 500, fontSize: 14,
            }}>
              {t.label}
              {t.count !== null && <span style={{ marginLeft: 6, color: T.muted, fontWeight: 500 }}>{t.count}</span>}
            </div>
          ))}
        </div>

        {/* Recipe grid */}
        <div style={{
          marginTop: 24,
          display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 18,
        }}>
          {[
            { p: 'tomato', t: 'Sunday short ribs over polenta', m: '3 hr 20 min' },
            { p: 'greens', t: 'Charred broccolini, anchovy butter', m: '22 min' },
            { p: 'lemon', t: 'Cardamom morning bun, lazy', m: '1 hr 10 min' },
            { p: 'cream', t: 'Pici cacio e pepe', m: '45 min' },
            { p: 'dark', t: 'Burnt-honey black pepper chicken', m: '50 min' },
            { p: 'blueb', t: 'Plum & pluot galette, rye crust', m: '1 hr 40 min' },
            { p: 'tomato', t: "Mara's bucatini all'amatriciana", m: '40 min' },
            { p: 'greens', t: 'Big-leaf herb salad', m: '11 min' },
          ].map((r, i) => (
            <GridCard key={i} photo={r.p} title={r.t} time={r.m} />
          ))}
        </div>
      </main>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 7. My Tray (Saved)
// ─────────────────────────────────────────────────────────────
function WebMyTray() {
  const collections = [
    { name: 'All saved', count: 38, photo: 'tomato', active: true },
    { name: 'To try', count: 14, photo: 'lemon' },
    { name: 'Mainstays', count: 9, photo: 'cream' },
    { name: 'Weeknight', count: 12, photo: 'greens' },
    { name: 'Sunday cooking', count: 6, photo: 'dark' },
    { name: 'Mom\'s recipes', count: 7, photo: 'blueb', private: true },
  ];
  return (
    <div className="screen" data-screen-label="Web · My Tray (saved)"
      style={{ background: T.bg, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <WebHeader active="mytray" />

      <main style={{ flex: 1, overflow: 'auto', padding: '32px 48px 48px', maxWidth: 1280, margin: '0 auto', width: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginBottom: 24 }}>
          <h1 className="serif" style={{ fontSize: 40, fontWeight: 400, margin: 0, letterSpacing: '-0.015em' }}>
            My Tray
          </h1>
          <div className="mono" style={{ fontSize: 11, color: T.muted, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
            38 saved · 5 collections
          </div>
        </div>

        {/* Collections row */}
        <div style={{
          display: 'flex', gap: 14, overflow: 'auto', paddingBottom: 8, marginBottom: 32,
        }}>
          {collections.map(c => (
            <div key={c.name} style={{
              flexShrink: 0, width: 200,
              border: c.active ? `2px solid ${T.primary}` : `1px solid ${T.hair}`,
              borderRadius: 4, overflow: 'hidden', cursor: 'pointer',
              background: T.surface,
            }}>
              <Photo variant={c.photo} style={{ height: 100 }} />
              <div style={{ padding: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span className="serif" style={{ fontSize: 17, color: T.text, fontWeight: 400 }}>{c.name}</span>
                  {c.private && <span className="mono" style={{ fontSize: 9, color: T.muted, letterSpacing: '0.12em', textTransform: 'uppercase' }}>· private</span>}
                </div>
                <div className="mono" style={{ fontSize: 10, color: T.muted, letterSpacing: '0.12em', textTransform: 'uppercase', marginTop: 4 }}>
                  {c.count} recipes
                </div>
              </div>
            </div>
          ))}
          {/* New collection */}
          <div style={{
            flexShrink: 0, width: 200, height: 162,
            border: `1px dashed ${T.border}`, borderRadius: 4,
            display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
            color: T.muted, gap: 8, cursor: 'pointer',
          }}>
            <IconPlus size={20}/>
            <span style={{ fontSize: 13, fontFamily: 'var(--serif)', fontStyle: 'italic' }}>New collection</span>
          </div>
        </div>

        {/* Saved list — same card style as Feed */}
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 20,
        }}>
          {[
            { p: 'tomato', t: 'Sunday short ribs over polenta', c: 'Mara Chen', col: 'Mainstays · cooked 2×', m: '3 hr 20 min · 11 ingredients' },
            { p: 'greens', t: 'Charred broccolini, anchovy butter', c: 'Devi Rao', col: 'Weeknight', m: '22 min · 6 ingredients' },
            { p: 'lemon', t: 'Cardamom morning bun, lazy', c: 'Theo Park', col: 'To try', m: '1 hr 10 min · 9 ingredients' },
            { p: 'cream', t: 'Pici cacio e pepe', c: 'Yuna Aoki', col: 'Mainstays', m: '45 min · 5 ingredients' },
            { p: 'dark', t: 'Burnt-honey chicken', c: 'Mara Chen', col: 'Sunday cooking', m: '50 min · 8 ingredients' },
            { p: 'blueb', t: 'Plum & pluot galette, rye crust', c: 'Jules Aman', col: 'To try', m: '1 hr 40 min · 10 ingredients' },
          ].map((r, i) => (
            <article key={i} style={{
              background: T.surface, borderRadius: 4, overflow: 'hidden',
              border: `1px solid ${T.hair}`,
              display: 'grid', gridTemplateColumns: '180px 1fr', gap: 0,
            }}>
              <Photo variant={r.p} style={{ height: 160 }} />
              <div style={{ padding: '14px 18px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                  <Avatar initial={r.c[0]} size={22} palette="warm" />
                  <span style={{ fontSize: 12, color: T.text }}>{r.c}</span>
                </div>
                <h4 className="serif" style={{ fontSize: 19, fontWeight: 400, lineHeight: 1.1, margin: '4px 0 6px' }}>{r.t}</h4>
                <div style={{ fontSize: 12, color: T.muted, marginBottom: 8 }}>{r.m}</div>
                <div className="mono" style={{
                  display: 'inline-block', fontSize: 9, color: T.primary,
                  letterSpacing: '0.12em', textTransform: 'uppercase',
                  padding: '3px 8px', background: 'rgba(165,214,167,0.25)', borderRadius: 99,
                }}>
                  {r.col}
                </div>
              </div>
            </article>
          ))}
        </div>
      </main>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 8. Comments — recipe with comments panel docked right
// ─────────────────────────────────────────────────────────────
function WebComments() {
  const comments = [
    { who: 'Devi Rao', u: '@devi.rao', p: 'sage', when: '2 hr', body: "Did this with boneless chuck because that's what I had. Worked beautifully — just shaved 30 minutes off the braise. The polenta tip about whisking in cold butter at the end is the move.", replies: [
      { who: 'Mara Chen', u: '@mara.cooks', p: 'warm', when: '1 hr', body: 'Yes! Chuck is great when you can find it well-marbled.', isCook: true },
    ]},
    { who: 'Theo Park', u: '@theo', p: 'amber', when: 'Yesterday', body: 'Subbed half the wine for tawny port. Heretical. Excellent.', replies: [] },
    { who: 'Yuna Aoki', u: '@yuna.20min', p: 'plum', when: '2d', body: 'Made a half batch in the same pot and reduced everything 30%. Came out the same. Forgiving recipe.', replies: [] },
    { who: 'Lior Bavli', u: '@lior', p: 'sky', when: '3d', body: 'How long can these sit in the braising liquid after cooking? Asking for a Sunday meal prep.', replies: [
      { who: 'Mara Chen', u: '@mara.cooks', p: 'warm', when: '3d', body: 'Honestly better the next day. I\'d cook through, refrigerate in the liquid, gently reheat covered for 30 min.', isCook: true },
    ]},
  ];
  return (
    <div className="screen" data-screen-label="Web · Comments (notes panel open)"
      style={{ background: T.bg, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <WebHeader showSearch={false} />

      <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '1fr 420px', minHeight: 0 }}>
        {/* Recipe in background, slightly dimmed */}
        <main style={{ overflow: 'auto', position: 'relative' }}>
          <Photo variant="tomato" style={{ height: 320 }} />
          <div style={{ padding: '32px 48px 48px', maxWidth: 840 }}>
            <div className="mono" style={{ fontSize: 11, color: T.primary, letterSpacing: '0.18em', textTransform: 'uppercase' }}>
              Mains · Beef · Slow
            </div>
            <h1 className="serif" style={{ fontSize: 52, fontWeight: 400, lineHeight: 1, margin: '10px 0 14px', letterSpacing: '-0.015em' }}>
              Sunday short ribs over polenta
            </h1>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
              <Avatar initial="M" size={36} palette="warm" />
              <div style={{ fontSize: 13 }}><b>Mara Chen</b> · 84 recipes · 428 followers</div>
            </div>
            <p style={{
              fontSize: 16, color: T.text, lineHeight: 1.65, fontFamily: 'var(--serif)', fontStyle: 'italic',
              maxWidth: 640, margin: '0 0 24px',
            }}>
              "Cooked this for my dad's birthday. He's a snob about short ribs. He had thirds."
            </p>
            <div style={{ background: T.surface, padding: 20, borderRadius: 4, border: `1px solid ${T.hair}`, color: T.muted, fontSize: 13, fontStyle: 'italic', fontFamily: 'var(--serif)' }}>
              Recipe continues below — ingredients, method, timers…
            </div>
          </div>
        </main>

        {/* Comments panel — docked right */}
        <aside style={{
          background: T.surface, borderLeft: `1px solid ${T.hair}`,
          boxShadow: '-8px 0 30px rgba(0,0,0,0.04)',
          display: 'flex', flexDirection: 'column',
        }}>
          {/* Header */}
          <div style={{
            padding: '20px 22px 14px', borderBottom: `1px solid ${T.hair}`,
            display: 'flex', alignItems: 'baseline', gap: 10,
          }}>
            <h2 className="serif" style={{ fontSize: 24, fontWeight: 400, margin: 0 }}>Cook's notes</h2>
            <span style={{ fontSize: 12, color: T.muted }}>· 6 from people who made it</span>
            <div style={{ flex: 1 }} />
            <IconClose size={16} style={{ color: T.muted }} />
          </div>

          {/* Comment list */}
          <div style={{ flex: 1, overflow: 'auto', padding: '8px 22px 0' }}>
            {comments.map((c, i) => (
              <div key={i} style={{ padding: '16px 0', borderBottom: `1px solid ${T.hair}` }}>
                <div style={{ display: 'grid', gridTemplateColumns: '32px 1fr', gap: 12 }}>
                  <Avatar initial={c.who[0]} size={32} palette={c.p}/>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
                      <span style={{ fontSize: 13, color: T.text, fontWeight: 600 }}>{c.who}</span>
                      <span style={{ fontSize: 11, color: T.muted }}>{c.u}</span>
                      <span className="mono" style={{ fontSize: 10, color: T.muted, letterSpacing: '0.06em', marginLeft: 'auto' }}>{c.when}</span>
                    </div>
                    <p style={{ fontSize: 13, color: T.text, lineHeight: 1.55, margin: '6px 0 4px' }}>{c.body}</p>
                    <button style={{ background: 'transparent', border: 0, color: T.muted, fontSize: 12, fontFamily: 'inherit', padding: '4px 0', cursor: 'pointer' }}>
                      Reply
                    </button>
                  </div>
                </div>
                {/* Replies — one level only */}
                {c.replies.map((r, ri) => (
                  <div key={ri} style={{
                    marginTop: 8, marginLeft: 32,
                    paddingLeft: 12, borderLeft: `2px solid ${T.hair}`,
                    display: 'grid', gridTemplateColumns: '28px 1fr', gap: 10,
                  }}>
                    <Avatar initial={r.who[0]} size={28} palette={r.p}/>
                    <div>
                      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
                        <span style={{ fontSize: 13, color: T.text, fontWeight: 600 }}>{r.who}</span>
                        {r.isCook && (
                          <span style={{
                            background: T.secondary, color: '#0f2611',
                            padding: '1px 7px', borderRadius: 99,
                            fontSize: 10, fontWeight: 600,
                          }}>Cook</span>
                        )}
                        <span className="mono" style={{ fontSize: 10, color: T.muted, letterSpacing: '0.06em', marginLeft: 'auto' }}>{r.when}</span>
                      </div>
                      <p style={{ fontSize: 13, color: T.text, lineHeight: 1.55, margin: '4px 0 0' }}>{r.body}</p>
                    </div>
                  </div>
                ))}
              </div>
            ))}
          </div>

          {/* Composer pinned at bottom */}
          <div style={{
            padding: 16, borderTop: `1px solid ${T.hair}`, background: T.bg,
            display: 'flex', gap: 10, alignItems: 'center',
          }}>
            <Avatar initial="E" size={32} />
            <div style={{
              flex: 1, height: 40, background: T.surface, borderRadius: 20,
              border: `1px solid ${T.border}`, padding: '0 14px',
              display: 'flex', alignItems: 'center',
              fontSize: 13, color: T.muted, fontStyle: 'italic', fontFamily: 'var(--serif)',
            }}>
              Cooked it? Leave a note…
            </div>
            <button style={{
              width: 40, height: 40, borderRadius: 20, border: 0,
              background: T.primary, color: '#fff',
              display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
            }}>
              <IconSend size={16}/>
            </button>
          </div>
        </aside>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 9. Followers / Following
// ─────────────────────────────────────────────────────────────
function WebFollowers() {
  const cooks = [
    { n: 'Devi Rao', u: '@devi.rao', p: 'sage', bio: 'Brooklyn · Vegetables before everything, one pan when possible.', following: true },
    { n: 'Theo Park', u: '@theo', p: 'amber', bio: 'Oakland · What\'s in the cabinet, what\'s about to turn.', following: true },
    { n: 'Yuna Aoki', u: '@yuna.20min', p: 'plum', bio: 'Portland · Lunch should be over in twenty minutes.', following: true },
    { n: 'Lior Bavli', u: '@lior', p: 'sky', bio: 'Tel Aviv · Chickpeas, citrus, the long Sunday breakfast.', following: false },
    { n: 'Jules Aman', u: '@jules.bakes', p: 'warm', bio: 'Montréal · Galettes, the occasional ill-advised cake.', following: false },
    { n: 'Soo Park', u: '@sooooo', p: 'sage', bio: 'Seoul → Brooklyn · Crispy edges. Steamed centers.', following: true },
    { n: 'Anya Reyes', u: '@anya.new', p: 'amber', bio: 'New to Trays · Currently learning braises.', following: false, newCook: true },
    { n: 'Ben Cohen', u: '@bencooks', p: 'plum', bio: 'New to Trays · Smoked & slow.', following: false, newCook: true },
  ];
  return (
    <div className="screen" data-screen-label="Web · Followers"
      style={{ background: T.bg, height: '100%' }}>
      <WebHeader showSearch={false} />

      <main style={{ maxWidth: 880, margin: '0 auto', padding: '32px 32px 48px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 8 }}>
          <button style={{ background: 'transparent', border: 0, color: T.muted, padding: 0, cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 13, fontFamily: 'inherit' }}>
            <IconArrowL size={14}/> Mara Chen
          </button>
        </div>
        <div style={{ display: 'flex', gap: 28, marginBottom: 18 }}>
          {[
            { id: 'followers', label: 'Followers', count: 428, active: true },
            { id: 'following', label: 'Following', count: 52 },
          ].map(t => (
            <div key={t.id} style={{
              padding: '8px 0', cursor: 'pointer',
              borderBottom: t.active ? `2px solid ${T.primary}` : '2px solid transparent',
              fontSize: 18, fontFamily: 'var(--serif)',
              color: t.active ? T.text : T.muted,
              fontWeight: t.active ? 400 : 400,
            }}>
              {t.label}<span style={{ marginLeft: 8, fontSize: 14, color: T.muted, fontFamily: 'var(--ui)' }}>{t.count}</span>
            </div>
          ))}
        </div>

        {/* Search field — appears since list > 20 */}
        <div style={{
          height: 40, borderRadius: 20, background: T.surface, border: `1px solid ${T.border}`,
          display: 'flex', alignItems: 'center', gap: 10, padding: '0 16px',
          color: T.muted, fontSize: 13, marginBottom: 18,
        }}>
          <IconSearch size={14}/>
          <span>Search 428 followers by name or username</span>
        </div>

        {/* List */}
        <div style={{ background: T.surface, borderRadius: 4, border: `1px solid ${T.hair}` }}>
          {cooks.map((c, i) => (
            <div key={i} style={{
              display: 'grid', gridTemplateColumns: '48px 1fr auto', gap: 14,
              padding: '16px 20px', alignItems: 'center',
              borderBottom: i < cooks.length - 1 ? `1px solid ${T.hair}` : '0',
            }}>
              <Avatar initial={c.n[0]} size={48} palette={c.p}/>
              <div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                  <span style={{ fontSize: 15, color: T.text, fontWeight: 600 }}>{c.n}</span>
                  <span style={{ fontSize: 12, color: T.muted }}>{c.u}</span>
                  {c.newCook && (
                    <span style={{
                      background: 'rgba(165,214,167,0.4)', color: '#2a5430',
                      padding: '2px 8px', borderRadius: 99,
                      fontSize: 10, fontFamily: 'var(--mono)', letterSpacing: '0.1em', textTransform: 'uppercase',
                    }}>New cook</span>
                  )}
                </div>
                <div style={{ fontSize: 13, color: T.muted, marginTop: 3, lineHeight: 1.4 }}>{c.bio}</div>
              </div>
              {c.following ? (
                <button className="btn ghost" style={{ height: 34, fontSize: 12 }}>Following</button>
              ) : (
                <button className="btn" style={{ height: 34, fontSize: 12, background: T.primary, padding: '0 14px' }}>Follow</button>
              )}
            </div>
          ))}
        </div>

        <div style={{ textAlign: 'center', marginTop: 18, fontSize: 13, color: T.muted, fontStyle: 'italic', fontFamily: 'var(--serif)' }}>
          Showing 8 of 428 · scroll for more
        </div>
      </main>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 10. Notifications
// ─────────────────────────────────────────────────────────────
function WebNotifications() {
  const items = [
    { kind: 'save', who: 'Maria Quintero', extra: 'and 3 others', p: 'sage', when: '12m', recipe: 'Sunday short ribs', photo: 'tomato' },
    { kind: 'comment', who: 'Devi Rao', p: 'sage', when: '1 hr', recipe: 'Sunday short ribs', photo: 'tomato',
      body: 'Did this with boneless chuck because that\'s what I had…' },
    { kind: 'follow', who: 'Lior Bavli', p: 'sky', when: '3 hr', bio: 'Tel Aviv · Chickpeas, citrus, the long Sunday breakfast.' },
    { kind: 'like', who: 'Theo Park', extra: 'and 12 others', p: 'amber', when: '5 hr', recipe: 'Charred broccolini', photo: 'greens' },
    { kind: 'cooked', who: 'Yuna Aoki', p: 'plum', when: 'Yesterday', recipe: 'Pici cacio e pepe', photo: 'cream',
      body: '"Made it Tuesday. The lemon hits."' },
    { kind: 'save', who: 'Soo Park', extra: 'and 8 others', p: 'sage', when: '2d', recipe: 'Burnt-honey chicken', photo: 'dark' },
    { kind: 'follow', who: 'Anya Reyes', p: 'amber', when: '3d', bio: 'New to Trays · Currently learning braises.' },
  ];
  const phrase = (it) => {
    switch (it.kind) {
      case 'save': return <><b>{it.who}</b>{it.extra && <> {it.extra}</>} saved your <em>{it.recipe}</em></>;
      case 'comment': return <><b>{it.who}</b> left a note on <em>{it.recipe}</em></>;
      case 'like': return <><b>{it.who}</b>{it.extra && <> {it.extra}</>} found your <em>{it.recipe}</em> helpful</>;
      case 'follow': return <><b>{it.who}</b> followed you</>;
      case 'cooked': return <><b>{it.who}</b> cooked your <em>{it.recipe}</em></>;
    }
  };
  return (
    <div className="screen" data-screen-label="Web · Notifications"
      style={{ background: T.bg, height: '100%' }}>
      <WebHeader />

      <main style={{ maxWidth: 720, margin: '0 auto', padding: '32px 32px 48px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginBottom: 24 }}>
          <h1 className="serif" style={{ fontSize: 40, fontWeight: 400, margin: 0, letterSpacing: '-0.015em' }}>
            Notes for you
          </h1>
          <div className="mono" style={{ fontSize: 11, color: T.muted, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
            7 today · 2 unread
          </div>
          <div style={{ flex: 1 }} />
          <button style={{ background: 'transparent', border: 0, fontSize: 13, color: T.primary, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
            Mark all read
          </button>
        </div>

        <div style={{ background: T.surface, borderRadius: 4, border: `1px solid ${T.hair}` }}>
          {items.map((it, i) => (
            <div key={i} style={{
              display: 'grid', gridTemplateColumns: '40px 1fr 80px', gap: 14,
              padding: '18px 22px', alignItems: 'center',
              borderBottom: i < items.length - 1 ? `1px solid ${T.hair}` : '0',
              background: i < 2 ? 'rgba(255,179,0,0.04)' : 'transparent',
              position: 'relative',
            }}>
              <Avatar initial={it.who[0]} size={40} palette={it.p}/>
              <div>
                <div style={{
                  fontSize: 16, color: T.text, lineHeight: 1.4,
                  fontFamily: 'var(--serif)',
                }}>
                  {phrase(it)}
                </div>
                {it.body && (
                  <div style={{ fontSize: 13, color: T.muted, marginTop: 4, fontStyle: 'italic', fontFamily: 'var(--serif)' }}>
                    {it.body}
                  </div>
                )}
                {it.bio && (
                  <div style={{ fontSize: 12, color: T.muted, marginTop: 4 }}>{it.bio}</div>
                )}
                <div className="mono" style={{ fontSize: 10, color: T.muted, letterSpacing: '0.12em', marginTop: 6 }}>
                  {it.when}
                </div>
              </div>
              {it.photo ? (
                <Photo variant={it.photo} style={{ width: 80, height: 80, borderRadius: 3 }} />
              ) : it.kind === 'follow' ? (
                <button className="btn" style={{ height: 32, fontSize: 12, background: T.primary, padding: '0 14px' }}>
                  Follow back
                </button>
              ) : <div/>}
              {i < 2 && (
                <div style={{
                  position: 'absolute', left: 8, top: '50%', transform: 'translateY(-50%)',
                  width: 6, height: 6, borderRadius: '50%', background: T.accent,
                }} />
              )}
            </div>
          ))}
        </div>

        <div style={{ marginTop: 18, fontSize: 12, color: T.muted, textAlign: 'center', fontStyle: 'italic', fontFamily: 'var(--serif)' }}>
          Quiet by design. We don't ping you for the algorithm's sake.
        </div>
      </main>
    </div>
  );
}

Object.assign(window, {
  WebSignin, WebFeed, WebFind, WebRecipe, WebCreate,
  WebProfile, WebMyTray, WebComments, WebFollowers, WebNotifications,
});
