### A Pluto.jl notebook ###
# v1.0.1

using Markdown
using InteractiveUtils

# ╔═╡ 4347613b-8e8e-489f-b2ab-e3265b30695b
# ╠═╡ show_logs = false
let
	import Pkg
	Pkg.activate(".")
end

# ╔═╡ 6037cc63-abea-4cc3-adb4-3c7995547fa3
let
	using WingModels, GLMakie
	set_theme!(theme_latexfonts())
end

# ╔═╡ 3346c443-2ccc-4d9f-a11d-c9f36af5731b
md"""
# How to define your own parameterisation of a planform

## 1. Create the custom planform type

Let's say we want a rectangular planform which tapers the chord length by some ratio at the tip.

This would require 2 parameters so we define our custom planform type as follows:

```julia
struct MyCustomPlanform <: AbstractPlanform
	c 			# root chord length
	tr 			# taper ratio
end
```

## 2. Define how the quarter chord and chord length changes along the span

**NB the quarter chord must always start at 0 at the root**

Here we define functions for how the quarter chord and the chord length should vary as functions of the spanwise position `y`. You should only edit the bit inside the function body. The syntax `p.xxx` gives you access to the parameters stored in your new planform type.

For our custom planform the quarter chord should remain at 0 throughout and the chord length should decrease from the root chord length at the root to a multiple of the root chord length specified by the taper ratio at the tip:

```julia
function WingModels.quarter_chord(y, p::MyCustomPlanform)
	return 0.0
end
```
```julia
function WingModels.chord(y, p::MyCustomPlanform)
	return p.c - y * (p.c * (1 - p.tr))
end
```

## 3. Create your custom wing object
Using the syntax below, pass values for your parameters to create an instance of your new planform type:

```julia
pl = MyCustomPlanform(0.5, 0.2)
```

Using a similiar process to define an aerofoil, these two objects can then create the full wing:

```julia
w = Wing(af, pl)
```

where `af` is a defined aerofoil object. To export this wing as an .STL file:

```julia
write_stl("my_custom_wing.stl", w; nchord=50, nspan=50)
```


---

"""

# ╔═╡ c3b80c72-3808-47a0-9b87-8264b9574013
struct MyCustomPlanform <: AbstractPlanform
	c
	tr
end

# ╔═╡ 21e343c8-54ae-4c52-9ab0-75f956ccb5a7
function WingModels.quarter_chord(y, p::MyCustomPlanform)
	return 0.0
end

# ╔═╡ 13276911-4eaa-466d-b5b4-6f933e0277f8
function WingModels.chord(y, p::MyCustomPlanform)
	return p.c - y*(p.c * (1 - p.tr))
end

# ╔═╡ ec5589a6-69d0-498e-ae6b-1042ac5797c7
pl = MyCustomPlanform(0.5, 0.2)

# ╔═╡ 3f9a9304-b7e1-4225-9228-3126ae11ae2b
let
	f = Figure()
	ax = Axis(f[1,1], autolimitaspect=1, yreversed=true, title="Your custom planform")
	pts = Point2f.(planform(pl; n=50))
	lines!(ax, pts)
	f
end

# ╔═╡ 47dd45c6-bc78-45d9-a2ba-9eb042f02518
af = NACA4(9,4,12)

# ╔═╡ e8828d6a-c6cc-4671-a304-90a18cbdca20
let
	f = Figure()
	ax = Axis(f[1,1], limits=(-0.1, 1.1, -0.6, 0.6), title="Aerofoil")
	pts = Point2f.(aerofoil(0.0, af; n=50))
	lines!(ax, pts)
	f
end

# ╔═╡ 49e789ed-c106-40c2-b9ee-029cbceaf73c
w = Wing(af, pl)

# ╔═╡ b9cff3b9-9109-41cd-8dbf-977bc8fabcf0
let
	f = Figure()
	ax = Axis3(f[1,1], aspect=:data, title="Your custom wing")
	pts = Point3f.(wing(w; nchord=50, nspan=50))
	faces = stack(get_conns(100, 50); dims=1)
	mesh!(ax, pts, faces)
	f
end

# ╔═╡ 11dbbfa2-4c9a-426b-a934-9f29b47ac49f
md"""
**Uncomment the below cell and run it to export your wing as an STL file**
"""

# ╔═╡ 1b76c177-4a31-4c09-a31e-5748aeb8b13a
# write_stl("choose_your_filename", w; nchord=50, nspan=50)

# ╔═╡ Cell order:
# ╟─4347613b-8e8e-489f-b2ab-e3265b30695b
# ╟─6037cc63-abea-4cc3-adb4-3c7995547fa3
# ╟─3346c443-2ccc-4d9f-a11d-c9f36af5731b
# ╠═c3b80c72-3808-47a0-9b87-8264b9574013
# ╠═21e343c8-54ae-4c52-9ab0-75f956ccb5a7
# ╠═13276911-4eaa-466d-b5b4-6f933e0277f8
# ╠═ec5589a6-69d0-498e-ae6b-1042ac5797c7
# ╟─3f9a9304-b7e1-4225-9228-3126ae11ae2b
# ╠═47dd45c6-bc78-45d9-a2ba-9eb042f02518
# ╟─e8828d6a-c6cc-4671-a304-90a18cbdca20
# ╠═49e789ed-c106-40c2-b9ee-029cbceaf73c
# ╟─b9cff3b9-9109-41cd-8dbf-977bc8fabcf0
# ╟─11dbbfa2-4c9a-426b-a934-9f29b47ac49f
# ╠═1b76c177-4a31-4c09-a31e-5748aeb8b13a
