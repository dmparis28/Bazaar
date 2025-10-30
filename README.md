Project "Bazaar" - Monorepo

This is the root of the "Bazaar" marketplace monorepo. It uses pnpm workspaces to manage the frontend, all microservices, and shared packages.

Our Project Structure

/apps: Contains all deployable applications.

/frontend: The Next.js customer and vendor-facing application.

/services/user-service: Manages user/vendor accounts, authentication, and profiles.

/services/product-service: Manages product listings, API definitions, and inventory.

/services/payment-service: (CDE) The secure, isolated SAQ D service for payments.

... (We will add subscription-service, billing-engine-service, etc., here later)

/packages: Contains all shared code, types, and utilities.

/shared-types: TypeScript definitions (DTOs, interfaces) shared across services.

🚀 Getting Started

Install pnpm:
If you don't have it, install it globally:

npm install -g pnpm


Install Dependencies:
From this root directory, run:

pnpm install


This will install all the dependencies for all the projects defined in the pnpm-workspace.yaml file.

Start Developing:
You can now run commands for individual projects from the root. For example, to start the Next.js frontend (once it's set up):

pnpm --filter frontend dev
