// shared.jsx — Shared building blocks for web + iOS.
// Tokens, photo placeholders, web header, recipe cards, iOS chrome.

const T = {
  primary: '#1B5E20',
  primaryDk: '#2E7D32',
  secondary: '#A5D6A7',
  accent: '#FFB300',
  bg: '#FAFAFA',
  surface: '#FFFFFF',
  text: '#212121',
  muted: '#757575',
  hair: '#ECECEC',
  border: '#E5E5E5',
  dBg: '#121212',
  dSurface: '#1E1E1E',
  dSurface2: '#262626',
  dText: '#E0E0E0',
  dMuted: '#8E8E8E',
  dHair: '#2A2A2A',
  dBorder: '#303030',
};

const Photo = ({ variant = '', label = '', style = {} }) => (
  <div className={'photo ' + variant} style={style}>
    {label && <span className="caption">{label}</span>}
  </div>
);

// Avatar dot with initials, with a small palette of warm tones
function Avatar({ initial = 'A', size = 36, palette = 'warm' }) {
  const palettes = {
    warm: ['#c08a4f', '#8a5a32'],
    sage: ['#7ca352', '#3d5a2a'],
    amber: ['#d4a83a', '#7a5e1a'],
    plum: ['#9c6a8a', '#5a3f50'],
    sky:  ['#7ca5b8', '#3e596a'],
  };
  const p = palettes[palette] || palettes.warm;
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0,
      background: `linear-gradient(135deg, ${p[0]}, ${p[1]})`,
      color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: 'var(--serif)', fontSize: size * 0.42, letterSpacing: '-0.01em',
    }}>{initial}</div>
  );
}

// Web top header — wordmark + nav + search + create + avatar
function WebHeader({ active = 'feed', showSearch = true }) {
  const link = (id, label, icon) => (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      fontSize: 14, color: id === active ? T.text : T.muted,
      fontWeight: id === active ? 600 : 500,
      borderBottom: id === active ? `2px solid ${T.primary}` : '2px solid transparent',
      padding: '22px 2px', cursor: 'pointer',
    }}>
      {icon}
      <span>{label}</span>
    </div>
  );
  return (
    <header style={{
      height: 64, background: T.surface, borderBottom: `1px solid ${T.hair}`,
      display: 'flex', alignItems: 'center', padding: '0 32px', gap: 28, flexShrink: 0,
    }}>
      <div className="serif" style={{ fontSize: 26, color: T.primary, fontWeight: 400 }}>
        Trays
      </div>
      <nav style={{ display: 'flex', gap: 22, marginLeft: 16 }}>
        {link('feed', 'Feed')}
        {link('find', 'Find')}
        {link('mytray', 'My Tray')}
      </nav>
      <div style={{ flex: 1 }} />
      {showSearch && (
        <div style={{
          height: 36, width: 320, borderRadius: 18,
          background: T.bg, border: `1px solid ${T.border}`,
          display: 'flex', alignItems: 'center', gap: 8, padding: '0 14px',
          color: T.muted, fontSize: 13,
        }}>
          <IconSearch size={15}/>
          <span>Search recipes, cooks, ingredients…</span>
        </div>
      )}
      <div style={{ position: 'relative' }}>
        <IconBell size={20} style={{ color: T.muted }}/>
        <div style={{
          position: 'absolute', top: -2, right: -2,
          width: 8, height: 8, borderRadius: '50%', background: T.accent,
        }} />
      </div>
      <button className="btn amber" style={{ height: 36, fontSize: 13, padding: '0 16px' }}>
        <IconPlus size={15} stroke={2.2}/> New recipe
      </button>
      <Avatar initial="E" size={36} />
    </header>
  );
}

// Recipe card — web feed/find/mytray
function RecipeCard({ photo, title, cook, avatarPalette, time, ingredients, tags = [], likes, saves, comments, saved = false }) {
  return (
    <article style={{
      background: T.surface, borderRadius: 4, overflow: 'hidden',
      border: `1px solid ${T.hair}`,
      display: 'grid', gridTemplateColumns: '380px 1fr', gap: 0,
    }}>
      <Photo variant={photo} style={{ height: 280 }} />
      <div style={{ padding: '20px 24px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
          <Avatar initial={cook[0]} size={28} palette={avatarPalette}/>
          <span style={{ fontSize: 13, color: T.text, fontWeight: 600 }}>{cook}</span>
          <span style={{ fontSize: 12, color: T.muted }}>· {time} ago</span>
        </div>
        <h3 className="serif" style={{
          fontSize: 28, lineHeight: 1.05, fontWeight: 400, margin: '0 0 10px', color: T.text,
        }}>{title}</h3>
        <div style={{ display: 'flex', gap: 14, fontSize: 12, color: T.muted, marginBottom: 12, alignItems: 'center' }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
            <IconClock size={12}/> {ingredients.time}
          </span>
          <span>· {ingredients.count} ingredients · {ingredients.tools} tools</span>
        </div>
        <p style={{ fontSize: 14, color: T.text, lineHeight: 1.55, margin: '0 0 14px' }}>
          {ingredients.teaser}
        </p>
        <div style={{ display: 'flex', gap: 6, marginBottom: 'auto' }}>
          {tags.map(t => <span key={t} style={{ padding: '3px 10px', background: T.bg, borderRadius: 99, fontSize: 11, color: T.muted }}>{t}</span>)}
        </div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 18, marginTop: 16, paddingTop: 14,
          borderTop: `1px solid ${T.hair}`, color: T.muted, fontSize: 12,
        }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
            <IconHeart size={14}/> {likes}
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
            <IconComment size={14}/> {comments}
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
            {saved ? <IconBookmarkF size={14} style={{ color: T.text }} /> : <IconBookmark size={14}/>} {saves}
          </span>
          <div style={{ flex: 1 }} />
          <IconShare size={14} />
        </div>
      </div>
    </article>
  );
}

// Compact grid card (profile / find empty state)
function GridCard({ photo, title, time, palette }) {
  return (
    <div style={{ position: 'relative', borderRadius: 4, overflow: 'hidden' }}>
      <Photo variant={photo} style={{ height: 240 }} />
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        padding: '24px 14px 12px',
        background: 'linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.7) 100%)',
        color: '#fff',
      }}>
        <h4 className="serif" style={{ fontSize: 18, lineHeight: 1.1, fontWeight: 400, margin: 0 }}>{title}</h4>
        <div className="mono" style={{ fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', opacity: 0.85, marginTop: 4 }}>
          {time}
        </div>
      </div>
    </div>
  );
}

// iOS header bar — wordmark, title, optional trailing
function IOSHeaderDark({ title, eyebrow, trailing }) {
  return (
    <div style={{
      paddingTop: 56, paddingBottom: 12, paddingLeft: 20, paddingRight: 20,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
        <div className="serif" style={{ fontSize: 20, color: T.secondary }}>Trays</div>
        {eyebrow && (
          <div className="mono" style={{ fontSize: 9, color: T.dMuted, letterSpacing: '0.14em', textTransform: 'uppercase' }}>
            {eyebrow}
          </div>
        )}
        <div style={{ flex: 1 }} />
        {trailing}
      </div>
      {title && (
        <h1 className="serif" style={{
          fontSize: 34, lineHeight: 1, margin: 0, color: T.dText, fontWeight: 400,
          letterSpacing: '-0.015em',
        }}>{title}</h1>
      )}
    </div>
  );
}

// iOS bottom tab bar
function IOSTabBar({ active = 'feed' }) {
  const tabs = [
    { id: 'feed', label: 'Feed', icon: <IconHome size={20}/> },
    { id: 'find', label: 'Find', icon: <IconSearch size={20}/> },
    { id: 'create', label: '', icon: <IconPlus size={22} stroke={2.4}/>, fab: true },
    { id: 'mytray', label: 'My Tray', icon: <IconBookmark size={20}/> },
    { id: 'profile', label: 'Profile', icon: <IconUser size={20}/> },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 30,
      paddingBottom: 30, paddingTop: 10,
      background: 'linear-gradient(180deg, rgba(18,18,18,0) 0%, rgba(18,18,18,0.85) 35%, rgba(18,18,18,1) 100%)',
      backdropFilter: 'blur(20px)',
      display: 'flex', justifyContent: 'space-around', alignItems: 'center', padding: '12px 16px 30px',
    }}>
      {tabs.map(t => (
        t.fab ? (
          <div key={t.id} style={{
            width: 52, height: 52, borderRadius: '50%',
            background: T.accent, color: '#2a1c00',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 8px 22px rgba(255,179,0,0.35)',
          }}>{t.icon}</div>
        ) : (
          <div key={t.id} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
            color: t.id === active ? T.dText : T.dMuted,
          }}>
            {t.icon}
            <span style={{ fontSize: 10, fontWeight: t.id === active ? 600 : 500 }}>{t.label}</span>
          </div>
        )
      ))}
    </div>
  );
}

// iOS recipe card — feed style, full width
function IOSRecipeCard({ photo, title, cook, avatarPalette, time, teaser, likes, saves, comments, saved = false, isDiscovery = false }) {
  return (
    <article style={{
      background: T.dSurface, borderRadius: 12, overflow: 'hidden',
      marginBottom: 14, border: '1px solid ' + T.dHair,
    }}>
      <div style={{ padding: '14px 16px 10px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <Avatar initial={cook[0]} size={32} palette={avatarPalette}/>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', gap: 6, alignItems: 'baseline' }}>
            <span style={{ fontSize: 13, color: T.dText, fontWeight: 600 }}>{cook}</span>
            {isDiscovery && (
              <span className="mono" style={{ fontSize: 9, color: T.secondary, letterSpacing: '0.12em', textTransform: 'uppercase' }}>
                · Suggested
              </span>
            )}
          </div>
          <div style={{ fontSize: 11, color: T.dMuted }}>{time} ago</div>
        </div>
        <IconBookmark size={16} style={{ color: T.dMuted }} />
      </div>
      <Photo variant={photo} style={{ height: 320 }} />
      <div style={{ padding: '14px 16px' }}>
        <h3 className="serif" style={{ fontSize: 22, fontWeight: 400, lineHeight: 1.1, margin: '0 0 8px', color: T.dText }}>
          {title}
        </h3>
        <div style={{ fontSize: 12, color: T.dMuted, lineHeight: 1.5 }}>{teaser}</div>
        <div style={{
          display: 'flex', gap: 18, marginTop: 14, paddingTop: 12,
          borderTop: '1px solid ' + T.dHair, color: T.dMuted, fontSize: 12, alignItems: 'center',
        }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
            <IconHeart size={14}/> {likes}
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
            <IconComment size={14}/> {comments}
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
            <IconBookmark size={14}/> {saves}
          </span>
          <div style={{ flex: 1 }} />
          <IconShare size={14}/>
        </div>
      </div>
    </article>
  );
}

Object.assign(window, {
  T, Photo, Avatar, WebHeader, RecipeCard, GridCard,
  IOSHeaderDark, IOSTabBar, IOSRecipeCard,
});
