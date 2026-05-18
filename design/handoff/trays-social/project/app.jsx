// app.jsx — Trays design canvas. Web + iOS, all 10 features.

function App() {
  return (
    <DesignCanvas title="Trays · Social cooking app" subtitle="Web (1280) + iOS (iPhone 15 Pro, dark default)">
      <DCSection id="auth" title="01 · Sign-in & onboarding"
        subtitle="Landing + sign-up on web · welcome screen explaining the three trays on iOS">
        <DCArtboard id="w-signin" label="Web · Sign-up" width={1280} height={860}>
          <WebSignin />
        </DCArtboard>
        <DCArtboard id="i-signin" label="iOS · Welcome" width={402} height={874}>
          <IOSSignin />
        </DCArtboard>
      </DCSection>

      <DCSection id="feed" title="02 · Feed"
        subtitle="Recipes from cooks you follow · discovery interleaved & clearly labeled · engagement muted">
        <DCArtboard id="w-feed" label="Web · Feed" width={1280} height={1100}>
          <WebFeed />
        </DCArtboard>
        <DCArtboard id="i-feed" label="iOS · Feed" width={402} height={874}>
          <IOSFeed />
        </DCArtboard>
      </DCSection>

      <DCSection id="find" title="03 · Search / Find"
        subtitle="Recipe-first search · filter chips · live results">
        <DCArtboard id="w-find" label="Web · Find" width={1280} height={1200}>
          <WebFind />
        </DCArtboard>
        <DCArtboard id="i-find" label="iOS · Find" width={402} height={874}>
          <IOSFind />
        </DCArtboard>
      </DCSection>

      <DCSection id="recipe" title="04 · Recipe Detail"
        subtitle="The most important screen · clean two-column on web · large method type on iOS · per-step amber timer">
        <DCArtboard id="w-recipe" label="Web · Recipe detail" width={1280} height={1700}>
          <WebRecipe />
        </DCArtboard>
        <DCArtboard id="i-recipe" label="iOS · Recipe detail" width={402} height={1080}>
          <IOSRecipe />
        </DCArtboard>
      </DCSection>

      <DCSection id="create" title="05 · Create Recipe"
        subtitle="Five-step form · 'writing a recipe page' framing · live card preview on web">
        <DCArtboard id="w-create" label="Web · Create — step 3 of 5" width={1280} height={900}>
          <WebCreate />
        </DCArtboard>
        <DCArtboard id="i-create" label="iOS · Create — step 3 of 5" width={402} height={874}>
          <IOSCreate />
        </DCArtboard>
      </DCSection>

      <DCSection id="profile" title="06 · Profile"
        subtitle="A cook's page · tabbed Recipes / Saved / About · 4-up grid on web · 3-up on mobile">
        <DCArtboard id="w-profile" label="Web · Profile" width={1280} height={1100}>
          <WebProfile />
        </DCArtboard>
        <DCArtboard id="i-profile" label="iOS · Profile" width={402} height={874}>
          <IOSProfile />
        </DCArtboard>
      </DCSection>

      <DCSection id="mytray" title="07 · My Tray (saved)"
        subtitle="The cook's saved recipes · horizontal collections row · user-creatable named groups">
        <DCArtboard id="w-mytray" label="Web · My Tray" width={1280} height={1100}>
          <WebMyTray />
        </DCArtboard>
        <DCArtboard id="i-mytray" label="iOS · My Tray" width={402} height={874}>
          <IOSMyTray />
        </DCArtboard>
      </DCSection>

      <DCSection id="comments" title="08 · Comments (Cook's notes)"
        subtitle="Calm threaded panel · opens on demand · right-docked on web · bottom sheet on iOS · Mint Whisper 'Cook' badge for the recipe author">
        <DCArtboard id="w-comments" label="Web · Comments panel docked" width={1280} height={900}>
          <WebComments />
        </DCArtboard>
        <DCArtboard id="i-comments" label="iOS · Comments bottom sheet" width={402} height={874}>
          <IOSComments />
        </DCArtboard>
      </DCSection>

      <DCSection id="followers" title="09 · Followers / Following"
        subtitle="Simple list · searchable when > 20 · no leaderboard, no suggestions injected">
        <DCArtboard id="w-followers" label="Web · Followers" width={1280} height={900}>
          <WebFollowers />
        </DCArtboard>
        <DCArtboard id="i-followers" label="iOS · Followers" width={402} height={874}>
          <IOSFollowers />
        </DCArtboard>
      </DCSection>

      <DCSection id="notifications" title="10 · Notifications"
        subtitle="Editorial phrasing in serif · grouped identical events · quiet by design">
        <DCArtboard id="w-notifications" label="Web · Notifications" width={1280} height={900}>
          <WebNotifications />
        </DCArtboard>
        <DCArtboard id="i-notifications" label="iOS · Notifications" width={402} height={874}>
          <IOSNotifications />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
