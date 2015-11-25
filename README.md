# In-App Products Manager

This is a slightly modified version of StoreManager provided in StoreKitSuite sample code which supports auto-retry and has slightly changed notification behaviour.

## Purpose

When using In-App Purchase, before buying things, Products have to be retrieved from the App Store. As suggested by the documentation before user ever come up to your app's In-App Store, the products information has to be alredy there.

## Architecture Decision

In terms of architecture, some kind of manager needed to accomplish that. The manager stays in memmory during the lifetime of an app session and can be accessed anytime while the app is running. Accesment is made in two ways:

1. Control fetching
2. Retrieve products information

## Usage

This is exactly what original StoreManager able to do. However, I wanted it to be more robust and complex :) The manager's `fetchProductInformationForIds:` method might be called as many times as you need the products information to be refreshed. 

When manager encounters an error, it schedules itself for an attempt to retry after 15 seconds. In case, something calls `fetchProductInformationForIds:` during this "waiting", the manager resets auto-retry and starts the request from scratch.

### TODO: add more usage notes

##TODO

* I plan to add some kind of **auto-refresh functionality** in the future, so the manager could be told once to maintain the product information refreshed during the app being active.
