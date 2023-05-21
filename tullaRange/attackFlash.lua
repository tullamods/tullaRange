--------------------------------------------------------------------------------
-- A reimplementation of the attack flash animation
--
-- The stock UI uses an OnUpdate handler for this. Ths version is implemented
-- using animations to be a bit more performant
--------------------------------------------------------------------------------

local _, Addon = ...

local flashAnimations = {}

local function startFlashing(button)
	local animation = flashAnimations[button]

	if not animation then
		animation = button.Flash:CreateAnimationGroup()
		animation:SetLooping("BOUNCE")

		local alpha = animation:CreateAnimation("ALPHA")
		alpha:SetDuration(Addon:GetFlashDuration())
		alpha:SetFromAlpha(0)
		alpha:SetToAlpha(0.7)
		alpha.owner = button

		flashAnimations[button] = animation
	end

	button.Flash:Show()
	animation:Play()
end

local function stopFlashing(button)
	local animation = flashAnimations[button]

	if animation then
		animation:Stop()
		button.Flash:Hide()
	end
end

function Addon.StartAttackAnimation(button)
	if button:IsVisible() then
		startFlashing(button)
	end
end

function Addon.UpdateAttackAnimation(button)
	if (button.flashing == 1 or button.flashing == true) and button:IsVisible() then
		startFlashing(button)
	else
		stopFlashing(button)
	end
end
