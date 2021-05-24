--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onValueChanged()
	if super and super.onValueChanged then
		super.onValueChanged()
	end
	CoinsWeight.onCoinsValueChanged(window.getDatabaseNode())
end