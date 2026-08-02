# Design: the living world

> Superseded on 2026-08-02 by `DESIGN-offline-long-road.md`.
> This document records the rejected location-based social direction.
> Do not continue its GPS, server, account, or shared-borough work.

Accepted 2026-08-02.

## The premise

Hobbitle is a location-based social settlement game.
The real world slowly becomes a shared fantasy civilisation through the routes its players actually walk.
It is not a focus app, a passive idle game, or a Pokemon GO reskin.

A player discovers place-bound rumours, travelers, materials, and building sites while they move through their real neighborhood.
Their discoveries make a personal bottle village unmistakably theirs.
The movement of many players changes a shared regional world.
Frequently walked routes become trade roads.
Enough local contribution can turn a place into a harbor, market, orchard, observatory, or festival ground.

The sentence a player should be able to tell a friend is: "The walk I take every day became a road in this world."

## The game loop

1. Move through a real place.
2. Discover a rumor, resource, traveler, or site.
3. Make a short decision that changes a personal village or a shared district.
4. Return to see the resulting construction, traffic, story, or invitation.
5. Visit friends and contribute to regional projects.

The game rewards discovery, identity, and belonging.
It must not rely on a battery-draining foreground simulation, fear of loss, pay-to-win power, or a chore checklist.

## The differentiators

**Living roads.** A designer does not place a road.
It becomes visible because people actually keep travelling that route.

**Local folklore.** Each coarse location cell has a persistent seeded story.
Two places can share a biome but never a legend.

**Player-authored boroughs.** Local contributions alter the type and character of a shared place.
Players compare places because their communities made different decisions, not because a leaderboard assigned a higher number.

**Personal villages.** A house grammar combines a player's discoveries, choices, local landscape, and seeded architecture.
The settlement is a collectible self-portrait rather than a generic base.

**Asynchronous cooperation.** A bridge, tower, market, or festival can collect thousands of small contributions over days.
It is not a timed raid that excludes people who cannot appear at a particular hour.

## First vertical slice - built 2026-08-02

This slice proves one claim locally before accounts, map data, or a server exist.
An injected route sample becomes a persistent visible trade road in the existing world map and reveals a claimable place-bound rumor.
`--route-reset --route=meadow-shore` produces the clean capture state.

The first implementation stores coarse fantasy-world cells rather than raw latitude and longitude.
That keeps the local prototype private and compact.
It also creates the right seam for a future trusted location service, which can submit validated cell crossings without changing the road renderer.

The current five-region world, builders, and food event are legacy prototype material.
They may be reused as visual and construction machinery, but they are not the released game's progression loop.
Paid locks have been removed.

## Technical shape

`RouteBook` owns route compression, crossing accumulation, place-bound rumor identity, persistence, and the interface that a future server will replace.
`CommunityRoads` turns the book's immutable road segments into low-cost world geometry.
`RumorMarks` is the custom-drawn map overlay that makes an unclaimed site readable without labels or numbers.
The input source is deliberately outside both modules.
The first source is a capture-only debug route.
The real source will later be a native iOS location bridge with explicit consent and a server-authoritative anti-spoofing path.

Do not save raw GPS trails in `Progress`.
Do not let a client decide shared progress once accounts exist.
Do not copy Pokemon GO's capture, gym, raid, Pokestop, XP, or daily-chore systems.
