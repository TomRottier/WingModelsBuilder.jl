module WingModelsBuilder

using GLMakie
using WingModels
using DelimitedFiles: readdlm

export main

const AEROFOIL_OPTIONS = Dict(
    "NACA 4 series" => (:naca, NACA4),
    "Flat plate" => (:plate, RectangularAerofoil),
    "Seagull" => (:seagull, LiuAerofoil),
    "Merganser" => (:merganser, LiuAerofoil),
    "Teal" => (:teal, LiuAerofoil),
    "Empirical" => (:empirical, EmpiricalAerofoil),
)
const AEROFOIL_PARAMETERS = Dict(
    :naca => ["m", "p", "t"],
    :plate => ["t"],
    :seagull => [],
    :merganser => [],
    :teal => [],
    :empirical => [],
)
const AVIAN_AEROFOIL_PARAMETERS = Dict(
    :seagull => [3.8735, -0.807, 0.771, -15.246, 26.482, -18.975, 4.6232, 0.14, 1.333, 0.05, 4.0],
    :merganser => [3.9385, 0.7466, 1.84, -23.1743, 58.3057, -64.3674, 25.7629, 0.14, 1.333, 0.05, 4.0],
    :teal => [3.9917, -0.3677, 0.0239, 1.7804, -13.6875, 18.276, -8.279, 0.11, 4.0, 0.05, 4.0],
)

const PLANFORM_OPTIONS = Dict(
    "Rectangular" => (:rect, RectangularPlanform),
    "Trapezoidal" => (:trap, TrapezoidalPlanform),
    "Elliptical" => (:elliptical, EllipticalPlanform),
    "Seagull" => (:seagull, LiuPlanform),
    "Merganser" => (:merganser, LiuPlanform),
    "Teal" => (:teal, LiuPlanform),
    "Empirical" => (:empirical, EmpiricalPlanform),
)
const PLANFORM_PARAMETERS = Dict(
    :rect => ["c₀"],
    :trap => ["r", "ϕ", "c₀", "x"],
    :elliptical => ["c₁", "c₂"],
    :seagull => [],
    :merganser => [],
    :teal => [],
    :empirical => [],
)
const AVIAN_PLANFORM_PARAMETERS = Dict(
    :seagull => [0.423, 0.485, 26.08, -209.92, 637.21, -945.068, 695.03, 0.388],
    :merganser => [0.383, 0.465, 39.1, -323.8, 978.7, -1417.0, 1001.0, 0.423],
    :teal => [0.536, 0.808, -66.1, 435.6, -1203.0, 1664.1, -1130.2, 0.545],
)

function populate_controls!(gl, key, file, params, params_dict)
    foreach(delete!, contents(gl))

    if key == :empirical
        Label(gl[1, 1], "Data file")
        tb = Textbox(gl[2, 1]; tellwidth=false, validator=isfile)

        on(tb.stored_string; priority=1) do s
            @debug "updated file" file[]
            file[] = s
        end
        return nothing
    end

    # parametric or preset
    params2 = params_dict[key]
    for (i, name) in enumerate(params2)
        Label(gl[i, 1], name)
        tb = Textbox(gl[i, 2]; placeholder=name, validator=Float64, tellwidth=false)
        on(tb.stored_string; priority=1) do s
            v = tryparse(Float64, s)
            params[][i] = v
            @debug "updated parameter[$i] " params[][i]
            notify(params)
        end
    end
    return nothing
end

function handle_selection!(name, options, param_dict, preset_dict, obj, type, params, file, controls_gl)
    (key, T) = options[name]
    obj.val = nothing
    type.val = T
    params.val = fill(nothing, length(param_dict[key]))
    @debug "reset object" obj.val
    @debug "updated type" type.val
    @debug "reset parameters" params.val
    @debug "reset file" file.val

    if haskey(preset_dict, key)
        params.val = preset_dict[key]
        foreach(notify, [type, params, obj])
    end

    populate_controls!(controls_gl, key, file, params, param_dict)
end

function change_parameters!(type, params, obj)
    @debug "parameters changed: " params
    if any(isnothing, params)
        @debug "not all parameters entered, not creating object"
        return nothing
    end

    if type[] isa Union{WingModels.EmpiricalAerofoil,WingModels.EmpiricalPlanform}
        @debug "empirical wing, no update"
        return nothing
    else
        obj[] = type[](params...)
        @debug "updated object " obj[]
    end
    return nothing
end

function change_file!(file, type, obj)
    @debug "file changed" file
    data = readdlm(file, ',')
    obj[] = type[](data)
    @debug "updated object" obj[]
    return nothing
end

function setup_export(gl, aerofoil_obj, planform_obj)
    # Label(gl[1, 1], "Export"; tellwidth=false)
    btn = Button(gl[1, 1]; label="export")
    tb_fn = Textbox(gl[1, 2];
        placeholder="Enter filename", validator=f -> splitext(f)[2] ∈ (".stl", ".txt"), tellwidth=false)
    tb_nc = Textbox(gl[1, 3];
        placeholder="N chord points", validator=Int, tellwidth=false)
    tb_ns = Textbox(gl[1, 4];
        placeholder="N span points", validator=Int, tellwidth=false)
    on(btn.clicks) do _
        if (isnothing(tb_nc.stored_string[]) || isnothing(tb_ns.stored_string[]) || isnothing(tb_fn.stored_string[]))
            @debug "export options not complete"
            return nothing
        end
        fn = tb_fn.stored_string[]
        nchord = tryparse(Int, tb_nc.stored_string[])
        nspan = tryparse(Int, tb_ns.stored_string[])

        ft = splitext(fn)[2]
        ft ∈ ("stl", "txt") && return
        export_fcn = ft == ".stl" ? write_stl : write_pts

        (isnothing(aerofoil_obj[]) || isnothing(planform_obj)) && (@debug "nothing to export"; return)
        w = Wing(aerofoil_obj[], planform_obj[])
        export_fcn(fn, w; nchord, nspan)
        @debug "exported wing object with filename" w fn
    end
    return nothing
end


function @main(args)
    f = Figure()

    # top level
    gl_plots = GridLayout(f[1, 1], 2, 1)
    gl_controls = GridLayout(f[1, 2], 2, 1)

    # plots
    gl_2d = GridLayout(gl_plots[2, 1], 1, 2)
    gl_aerofoil = GridLayout(gl_2d[1, 1], 2, 1)
    ax_wing = Axis3(gl_plots[1, 1]; aspect=:data)
    ax_aerofoil = Axis(gl_aerofoil[2, 1];
        title="aerofoil", autolimitaspect=1, xticklabelspace=10.0, yticklabelspace=10.0)
    ax_planform = Axis(gl_2d[1, 2];
        title="planform", autolimitaspect=1, xticklabelspace=10.0, yticklabelspace=10.0, yreversed=true,)
    spanwise_slider = Slider(gl_aerofoil[1, 1];
        range=0.0:0.01:1.0, startvalue=0.0, tellwidth=false)

    # inputs top level
    gl_panels = GridLayout(gl_controls[1, 1], 1, 2)
    gl_export = GridLayout(gl_controls[2, 1])

    # aerofoil inputs
    gl_aerofoil_panel = GridLayout(gl_panels[1, 1]; tellwidth=false, tellheight=false)
    aerofoil_menu = Menu(
        gl_aerofoil_panel[1, 1];
        options=collect(keys(AEROFOIL_OPTIONS)), default="Flat plate"
    )
    gl_aerofoil_controls = GridLayout(gl_aerofoil_panel[2, 1]; tellheight=false, tellwidth=false, valign=:top)

    # planform inputs
    gl_planform_panel = GridLayout(gl_panels[1, 2]; tellwidth=false, tellheight=false)
    planform_menu = Menu(
        gl_planform_panel[1, 1];
        options=collect(keys(PLANFORM_OPTIONS)), default="Rectangular"
    )
    gl_planform_controls = GridLayout(gl_planform_panel[2, 1]; tellheight=false, tellwidth=false, valign=:top)

    # aerofoil
    aerofoil_obj = Observable{Any}(nothing)
    aerofoil_type = Observable{Any}(nothing)
    aerofoil_params = Observable(Vector{Union{Float64,Nothing}}())
    aerofoil_file = Observable("")
    on(aerofoil_menu.selection) do name
        handle_selection!(name, AEROFOIL_OPTIONS, AEROFOIL_PARAMETERS, AVIAN_AEROFOIL_PARAMETERS, aerofoil_obj, aerofoil_type, aerofoil_params, aerofoil_file, gl_aerofoil_controls)
    end
    on(aerofoil_params) do params
        change_parameters!(aerofoil_type, params, aerofoil_obj)
    end
    on(aerofoil_file) do file
        change_file!(file, aerofoil_type, aerofoil_obj)
    end

    aerofoil_pts = @lift begin
        isnothing($aerofoil_obj) && return Point2{Float64}[]
        pts = WingModels.aerofoil($(spanwise_slider.value), $aerofoil_obj; n=100)
        @debug "generated new aerofoil points at spanwise position" $aerofoil_obj $(spanwise_slider.value)
        pts
    end
    lines!(ax_aerofoil, aerofoil_pts)

    # planform
    planform_obj = Observable{Any}(nothing)
    planform_type = Observable{Any}(nothing)
    planform_params = Observable(Vector{Union{Float64,Nothing}}())
    planform_file = Observable("")
    on(planform_menu.selection) do name
        handle_selection!(name, PLANFORM_OPTIONS, PLANFORM_PARAMETERS, AVIAN_PLANFORM_PARAMETERS, planform_obj, planform_type, planform_params, planform_file, gl_planform_controls)
    end
    on(planform_params) do params
        change_parameters!(planform_type, params, planform_obj)
    end
    on(planform_file) do file
        change_file!(file, planform_type, planform_obj)
    end

    planform_pts = @lift begin
        isnothing($planform_obj) && return Point2{Float64}[]
        pts = WingModels.planform($planform_obj; n=100)
        @debug "generated new planform points" $planform_obj
        pts
    end
    lines!(ax_planform, planform_pts)

    wing_pts = @lift begin
        (isnothing($planform_obj) || isnothing($aerofoil_obj)) && return fill(Point3f(0., 0., 0.), 3)
        pts = WingModels.wing($aerofoil_obj, $planform_obj; nchord=50, nspan=50)
    end
    wing_conns = @lift begin
        (isnothing($planform_obj) || isnothing($aerofoil_obj)) && return [1 2 3]
        stack(get_conns(100, 50); dims=1)
    end
    mesh!(ax_wing, wing_pts, wing_conns)

    onany(aerofoil_pts, planform_pts, wing_pts) do _, _, _
        foreach(autolimits!, [ax_aerofoil, ax_planform, ax_wing])
    end


    # export panel
    setup_export(gl_export, aerofoil_obj, planform_obj)

    wait(display(f))
    return 0
end




end # module WingModelsBuilder