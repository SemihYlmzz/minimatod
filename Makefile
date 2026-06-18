# Minimatod — deploy to Vercel.
#
#   make deploy-website   ->  minimatod.com      (marketing site)
#   make deploy-webapp    ->  app.minimatod.com  (the Flutter app)

ORG_ID          := team_b7fYZJQd2xlUKFIcNnUjrN0d
SITE_PROJECT_ID := prj_Z8bH1a6v8QVCGbvGlnudrKB1tyzV
APP_PROJECT_ID  := prj_JE15rAoG7SrAgL5qJEnYrS41H5mP

.PHONY: deploy-website deploy-webapp

deploy-website:
	cd website && VERCEL_ORG_ID=$(ORG_ID) VERCEL_PROJECT_ID=$(SITE_PROJECT_ID) vercel deploy --prod --yes

deploy-webapp:
	cd minimatod && fvm flutter build web --release
	cd minimatod/build/web && VERCEL_ORG_ID=$(ORG_ID) VERCEL_PROJECT_ID=$(APP_PROJECT_ID) vercel deploy --prod --yes
