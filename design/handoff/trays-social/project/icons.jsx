// icons.jsx — minimal line icons

const Icon = ({ size = 18, stroke = 1.6, children, style = {} }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth={stroke}
    strokeLinecap="round" strokeLinejoin="round"
    style={{ display: 'block', flexShrink: 0, ...style }}>
    {children}
  </svg>
);

const IconSearch = (p) => <Icon {...p}><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></Icon>;
const IconClock = (p) => <Icon {...p}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></Icon>;
const IconBookmark = (p) => <Icon {...p}><path d="M6 3h12v18l-6-4-6 4V3z"/></Icon>;
const IconBookmarkF = (p) => <Icon {...p}><path d="M6 3h12v18l-6-4-6 4V3z" fill="currentColor"/></Icon>;
const IconPlus = (p) => <Icon {...p}><path d="M12 5v14M5 12h14"/></Icon>;
const IconChev = (p) => <Icon {...p}><path d="M9 6l6 6-6 6"/></Icon>;
const IconChevL = (p) => <Icon {...p}><path d="M15 6l-6 6 6 6"/></Icon>;
const IconChevDown = (p) => <Icon {...p}><path d="M6 9l6 6 6-6"/></Icon>;
const IconFlame = (p) => <Icon {...p}><path d="M12 3c1 4 5 5 5 10a5 5 0 11-10 0c0-3 2-3 2-7 2 1 3 1 3 -3z"/></Icon>;
const IconLeaf = (p) => <Icon {...p}><path d="M20 4c-9 0-15 5-15 12 0 2 1 3 3 4 7 0 12-6 12-16z"/><path d="M5 20l8-8"/></Icon>;
const IconPan = (p) => <Icon {...p}><circle cx="10" cy="13" r="6"/><path d="M16 11l6-2"/></Icon>;
const IconKnife = (p) => <Icon {...p}><path d="M3 21l8-8"/><path d="M11 13l5-5c2-2 5-3 6-3-1 3-2 5-4 7l-5 5"/></Icon>;
const IconWhisk = (p) => <Icon {...p}><path d="M12 3v8"/><path d="M8 11c0 4 1 7 4 10 3-3 4-6 4-10"/><path d="M9 14h6M10 17h4"/></Icon>;
const IconCamera = (p) => <Icon {...p}><path d="M3 8h4l2-3h6l2 3h4v12H3V8z"/><circle cx="12" cy="13" r="4"/></Icon>;
const IconBell = (p) => <Icon {...p}><path d="M6 18h12l-2-3v-4a4 4 0 10-8 0v4l-2 3z"/><path d="M10 21h4"/></Icon>;
const IconUser = (p) => <Icon {...p}><circle cx="12" cy="8" r="4"/><path d="M4 21c1-5 5-7 8-7s7 2 8 7"/></Icon>;
const IconList = (p) => <Icon {...p}><path d="M8 6h13M8 12h13M8 18h13"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/></Icon>;
const IconCheck = (p) => <Icon {...p}><path d="M4 12l5 5 11-12"/></Icon>;
const IconArrowR = (p) => <Icon {...p}><path d="M5 12h14M13 6l6 6-6 6"/></Icon>;
const IconArrowL = (p) => <Icon {...p}><path d="M19 12H5M11 18l-6-6 6-6"/></Icon>;
const IconClose = (p) => <Icon {...p}><path d="M6 6l12 12M18 6L6 18"/></Icon>;
const IconBolt = (p) => <Icon {...p}><path d="M13 2L4 14h6l-1 8 9-12h-6l1-8z"/></Icon>;
const IconHome = (p) => <Icon {...p}><path d="M3 11l9-7 9 7v10h-6v-7H9v7H3V11z"/></Icon>;
const IconHeart = (p) => <Icon {...p}><path d="M12 20s-7-4.5-9-9a5 5 0 019-3 5 5 0 019 3c-2 4.5-9 9-9 9z"/></Icon>;
const IconComment = (p) => <Icon {...p}><path d="M4 5h16v11H9l-5 4V5z"/></Icon>;
const IconShare = (p) => <Icon {...p}><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="M8 11l8-4M8 13l8 4"/></Icon>;
const IconCookpot = (p) => <Icon {...p}><path d="M4 9h16v8a3 3 0 01-3 3H7a3 3 0 01-3-3V9z"/><path d="M2 9h20M8 6c0-1 1-2 2-2M14 6c0-1 1-2 2-2"/></Icon>;
const IconImage = (p) => <Icon {...p}><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.5"/><path d="M21 16l-5-5-9 9"/></Icon>;
const IconSliders = (p) => <Icon {...p}><path d="M4 6h12M20 6h-1M4 12h6M14 12h6M4 18h10M18 18h2"/><circle cx="17" cy="6" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="16" cy="18" r="2"/></Icon>;
const IconSend = (p) => <Icon {...p}><path d="M3 11l18-8-8 18-2-8-8-2z"/></Icon>;
const IconGrid = (p) => <Icon {...p}><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></Icon>;

Object.assign(window, {
  Icon, IconSearch, IconClock, IconBookmark, IconBookmarkF, IconPlus, IconChev, IconChevL,
  IconChevDown, IconFlame, IconLeaf, IconPan, IconKnife, IconWhisk, IconCamera,
  IconBell, IconUser, IconList, IconCheck, IconArrowR, IconArrowL, IconClose,
  IconBolt, IconHome, IconHeart, IconComment, IconShare, IconCookpot,
  IconImage, IconSliders, IconSend, IconGrid,
});
