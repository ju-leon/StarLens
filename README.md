![Icon-83 5@2x](https://user-images.githubusercontent.com/31135823/235184765-f4d2b1ef-bf1e-4b54-9490-1cde26b60c57.png)

# StarLens

StarGazer makes you a professional astro photographer, with the push of a button.

Using advanced algorithms and artificial intelligence, hundreds of images are combined into a single, bright photo of the night sky. This allows you take ultra long exposures, while Stargazer stabilizes the night sky for you. While tracking the sky, a timelapse of the rotating night sky is created.

## Tracking

When taking pictures of the night sky, long exposures are essential to capturing all the little details. The longer you shoot, the more light your camera can capture. However, there's one problem: The night sky is moving, slowly, but surely. Professionals use expensive equipment to counteract the movements of the earth.

StarGazer solves this problem by tracking the night sky along multiple photos, and automatically aligning photos. This allows you to take ultra long exposures without getting star trails.

Bad photos are automatically recognized and not added onto the stack not to ruin your image.

![stacking](https://user-images.githubusercontent.com/31135823/235184119-8ed4cce4-4ded-4bcb-89cb-8781174ec8f4.gif)

## Sky Enhancement

Using a custom trained segementation model, the sky in the image is recognized and segmented.
For the segmentation model, refer to the following repo:
https://github.com/ju-leon/SkySegmentation

The dataset is currently not public. Please contact me directly if you need access.
Overview over the training process can be found on WandB
https://wandb.ai/leonjungemeyer/stargazer-segmentation

![segmentation_389_f4ebfe1e3be7957d2d87](https://user-images.githubusercontent.com/31135823/235187309-41c3d4eb-c8ba-44c5-a31d-8c4f2a6dbd44.png)
![segmentation_191_524f472014ba4177933b](https://user-images.githubusercontent.com/31135823/235187428-9ab29d78-ec94-4cd8-bec6-b47d4250b697.png)
![download](https://user-images.githubusercontent.com/31135823/235188081-91bb2e97-97b9-4717-9e32-4bb12396d22c.png)

Afterwards, the stars in the sky are artifically enhanced using a UNet trained to recognize and enhance stars.
This model, based on the few stars that a camera sensor in a phone is able to recognize, can generate structures that the signal to noise ratio from a normal phone sensor would never allow to make visible.

The training of the enhancement model is located here:
https://github.com/ju-leon/SkyEnhancement

Overview over the training process can be found on WandB:
https://wandb.ai/leonjungemeyer/stargazer-enhance

![segmentation_649_94b8ed8d86007d7930ba](https://user-images.githubusercontent.com/31135823/235186371-18e5575d-d470-4322-af64-4eb62f65116f.png)
![segmentation_649_77ddb0128680737aa977-1](https://user-images.githubusercontent.com/31135823/235186586-70cdf678-890f-48f6-817b-37459c7e76b9.png)

![Screenshot 2023-04-28 at 17 28 57](https://user-images.githubusercontent.com/31135823/235189946-2f659f22-000a-4731-9f8b-dca1ae5e69ee.png)

![screenshot](https://user-images.githubusercontent.com/31135823/235184191-88f2e89b-4530-4879-8215-5a1b4d177519.png)
