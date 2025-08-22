DASHBOARD — Role-aware Home
Purpose

Provide a simple home screen after login with:

Greeting + current user role

Quick navigation to modules (future)

Status tiles (placeholders until modules arrive)

Data & Dependencies

Requires current Auth user

Requires Firestore users/{uid} for displayName, role, status

Optional Config (future-ready)

Collection: dashboardConfigs/{role}

{
  "role": "admin|store|designer|engineer|accounts",
  "tiles": [
    { "id": "quick_users", "label": "Users", "icon": "people", "route": "/users" },
    { "id": "quick_inventory", "label": "Inventory", "icon": "inventory", "route": "/inventory" }
  ]
}

For this phase, tiles can be hardcoded by role. Config can be added later.

Features

Show user email + role on header.

Role-based Quick Actions (buttons) — placeholders for now.

Sign out from app bar.

Empty states handled gracefully.

UX / Layout

AppBar: “BarOps — Dashboard”

Body:

Card: “Welcome, {displayName}”

Text: “Role: {role}”

Grid (2–4 columns): Quick actions based on role

If status != active → show warning and disable actions

Workflows

On load: listen to auth state

If user null → go to Login

If user present → stream users/{uid}

Render role-aware UI

Sign out → Login

Access Control (UI-level)

If status == suspended → disable actions and show message

Admin sees “User Management” quick action; others don’t

Performance

Single Firestore doc stream (users/{uid})

Debounce renders; dispose listeners on logout

Test Checklist

Shows correct name/role

Admin sees “User Management”, others don’t

Suspended user shows blocked UI

Sign out returns to Login

